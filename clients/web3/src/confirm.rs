use crate::{Hmy, HmyFilter};

use futures::{Future, StreamExt};
use std::time::Duration;
use web3::{
    api::Namespace,
    error,
    types::{Bytes, TransactionReceipt, TransactionRequest, H256, U64},
    Transport,
};

/// Checks whether an event has been confirmed.
pub trait ConfirmationCheck {
    /// Future resolved when is known whether an event has been confirmed.
    type Check: Future<Output = error::Result<Option<U64>>>;

    /// Should be called to get future which resolves when confirmation state is known.
    fn check(&self) -> Self::Check;
}

impl<F, T> ConfirmationCheck for F
where
    F: Fn() -> T,
    T: Future<Output = error::Result<Option<U64>>>,
{
    type Check = T;

    fn check(&self) -> Self::Check {
        (*self)()
    }
}

/// Should be used to wait for confirmations
pub async fn wait_for_confirmations<T, V, F>(
    hmy: Hmy<T>,
    hmy_filter: HmyFilter<T>,
    poll_interval: Duration,
    confirmations: usize,
    check: V,
) -> error::Result<()>
where
    T: Transport,
    V: ConfirmationCheck<Check = F>,
    F: Future<Output = error::Result<Option<U64>>>,
{
    let filter = hmy_filter.create_blocks_filter().await?;
    // TODO #396: The stream should have additional checks.
    // * We should not continue calling next on a stream that has completed (has returned None). We expect this to never
    //   happen for the blocks filter but to be safe we should handle this case for example by `fuse`ing the stream or
    //   erroring when it does complete.
    // * We do not handle the case where the stream returns an error which means we are wrongly counting it as a
    //   confirmation.
    let filter_stream = filter.stream(poll_interval).skip(confirmations);
    futures::pin_mut!(filter_stream);
    loop {
        let _ = filter_stream.next().await;
        if let Some(confirmation_block_number) = check.check().await? {
            let block_number = hmy.block_number().await?;
            if confirmation_block_number.low_u64() + confirmations as u64 <= block_number.low_u64()
            {
                return Ok(());
            }
        }
    }
}

async fn transaction_receipt_block_number_check<T: Transport>(
    hmy: &Hmy<T>,
    hash: H256,
) -> error::Result<Option<U64>> {
    let receipt = hmy.transaction_receipt(hash).await?;
    Ok(receipt.and_then(|receipt| receipt.block_number))
}

async fn send_transaction_with_confirmation_<T: Transport>(
    hash: H256,
    transport: T,
    poll_interval: Duration,
    confirmations: usize,
) -> error::Result<TransactionReceipt> {
    let hmy = Hmy::new(transport.clone());
    if confirmations > 0 {
        let confirmation_check = || transaction_receipt_block_number_check(&hmy, hash);
        let hmy_filter = HmyFilter::new(transport.clone());
        let hmy = hmy.clone();
        wait_for_confirmations(
            hmy,
            hmy_filter,
            poll_interval,
            confirmations,
            confirmation_check,
        )
        .await?;
    }
    // TODO #397: We should remove this `expect`. No matter what happens inside the node, this shouldn't be a panic.
    let receipt = hmy
        .transaction_receipt(hash)
        .await?
        .expect("receipt can't be null after wait for confirmations; qed");
    Ok(receipt)
}

/// Sends transaction and returns future resolved after transaction is confirmed
pub async fn send_transaction_with_confirmation<T>(
    transport: T,
    tx: TransactionRequest,
    poll_interval: Duration,
    confirmations: usize,
) -> error::Result<TransactionReceipt>
where
    T: Transport,
{
    let hash = Hmy::new(&transport).send_transaction(tx).await?;
    send_transaction_with_confirmation_(hash, transport, poll_interval, confirmations).await
}

/// Sends raw transaction and returns future resolved after transaction is confirmed
pub async fn send_raw_transaction_with_confirmation<T>(
    transport: T,
    tx: Bytes,
    poll_interval: Duration,
    confirmations: usize,
) -> error::Result<TransactionReceipt>
where
    T: Transport,
{
    let hash = Hmy::new(&transport).send_raw_transaction(tx).await?;
    send_transaction_with_confirmation_(hash, transport, poll_interval, confirmations).await
}
