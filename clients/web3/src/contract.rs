use crate::{confirm, Hmy};

use futures::Future;
use web3::{
    api::Namespace,
    contract::{
        self,
        tokens::{Detokenize, Tokenize},
        Options,
    },
    error, ethabi,
    types::{
        Address, BlockId, Bytes, CallRequest, FilterBuilder, TransactionReceipt,
        TransactionRequest, U256,
    },
    Transport,
};

use std::time::Duration;

/// Harmony Contract Interface
#[derive(Debug, Clone)]
pub struct HmyContract<T: Transport> {
    address: Address,
    hmy: Hmy<T>,
    abi: ethabi::Contract,
}

impl<T: Transport> HmyContract<T> {
    /// Creates new Contract Interface given blockchain address and ABI
    pub fn new(hmy: Hmy<T>, address: Address, abi: ethabi::Contract) -> Self {
        HmyContract { address, hmy, abi }
    }

    /// Creates new Contract Interface given blockchain address and JSON containing ABI
    pub fn from_json(hmy: Hmy<T>, address: Address, json: &[u8]) -> ethabi::Result<Self> {
        let abi = ethabi::Contract::load(json)?;
        Ok(Self::new(hmy, address, abi))
    }

    /// Get the underlying contract ABI.
    pub fn abi(&self) -> &ethabi::Contract {
        &self.abi
    }

    /// Returns contract address
    pub fn address(&self) -> Address {
        self.address
    }

    /// Execute a contract function and wait for confirmations
    pub async fn call_with_confirmations(
        &self,
        func: &str,
        params: impl Tokenize,
        from: Address,
        options: Options,
        confirmations: usize,
    ) -> error::Result<TransactionReceipt> {
        let poll_interval = Duration::from_secs(1);

        let fn_data = self
            .abi
            .function(func)
            .and_then(|function| function.encode_input(&params.into_tokens()[..]))
            // TODO [ToDr] SendTransactionWithConfirmation should support custom error type (so that we can return
            // `contract::Error` instead of more generic `Error`.
            .map_err(|err| error::Error::Decoder(format!("{:?}", err)))?;
        let transaction_request = TransactionRequest {
            from,
            to: Some(self.address),
            gas: options.gas,
            gas_price: options.gas_price,
            value: options.value,
            nonce: options.nonce,
            data: Some(Bytes(fn_data)),
            condition: options.condition,
            transaction_type: options.transaction_type,
            access_list: options.access_list,
        };
        confirm::send_transaction_with_confirmation(
            self.hmy.transport().clone(),
            transaction_request,
            poll_interval,
            confirmations,
        )
        .await
    }

    /// Estimate gas required for this function call.
    pub async fn estimate_gas<P>(
        &self,
        func: &str,
        params: P,
        from: Address,
        options: Options,
    ) -> contract::Result<U256>
    where
        P: Tokenize,
    {
        let data = self
            .abi
            .function(func)?
            .encode_input(&params.into_tokens())?;
        self.hmy
            .estimate_gas(
                CallRequest {
                    from: Some(from),
                    to: Some(self.address),
                    gas: options.gas,
                    gas_price: options.gas_price,
                    value: options.value,
                    data: Some(Bytes(data)),
                    transaction_type: options.transaction_type,
                    access_list: options.access_list,
                },
                None,
            )
            .await
            .map_err(Into::into)
    }

    /// Call constant function
    pub fn query<R, A, B, P>(
        &self,
        func: &str,
        params: P,
        from: A,
        options: Options,
        block: B,
    ) -> impl Future<Output = contract::Result<R>> + '_
    where
        R: Detokenize,
        A: Into<Option<Address>>,
        B: Into<Option<BlockId>>,
        P: Tokenize,
    {
        let result = self
            .abi
            .function(func)
            .and_then(|function| {
                function
                    .encode_input(&params.into_tokens())
                    .map(|call| (call, function))
            })
            .map(|(call, function)| {
                let call_future = self.hmy.call(
                    CallRequest {
                        from: from.into(),
                        to: Some(self.address),
                        gas: options.gas,
                        gas_price: options.gas_price,
                        value: options.value,
                        data: Some(Bytes(call)),
                        transaction_type: options.transaction_type,
                        access_list: options.access_list,
                    },
                    block.into(),
                );
                (call_future, function)
            });
        // NOTE for the batch transport to work correctly, we must call `transport.execute` without ever polling the future,
        // hence it cannot be a fully `async` function.
        async {
            let (call_future, function) = result?;
            let bytes = call_future.await?;
            let output = function.decode_output(&bytes.0)?;
            R::from_tokens(output)
        }
    }

    /// Find events matching the topics.
    pub async fn events<A, B, C, R>(
        &self,
        event: &str,
        topic0: A,
        topic1: B,
        topic2: C,
    ) -> contract::Result<Vec<R>>
    where
        A: Tokenize,
        B: Tokenize,
        C: Tokenize,
        R: Detokenize,
    {
        fn to_topic<A: Tokenize>(x: A) -> ethabi::Topic<ethabi::Token> {
            let tokens = x.into_tokens();
            if tokens.is_empty() {
                ethabi::Topic::Any
            } else {
                tokens.into()
            }
        }

        let res = self.abi.event(event).and_then(|ev| {
            let filter = ev.filter(ethabi::RawTopicFilter {
                topic0: to_topic(topic0),
                topic1: to_topic(topic1),
                topic2: to_topic(topic2),
            })?;
            Ok((ev.clone(), filter))
        });
        let (ev, filter) = match res {
            Ok(x) => x,
            Err(e) => return Err(e.into()),
        };

        let logs = self
            .hmy
            .logs(FilterBuilder::default().topic_filter(filter).build())
            .await?;
        logs.into_iter()
            .map(move |l| {
                let log = ev.parse_log(ethabi::RawLog {
                    topics: l.topics,
                    data: l.data.0,
                })?;

                Ok(R::from_tokens(
                    log.params.into_iter().map(|x| x.value).collect::<Vec<_>>(),
                )?)
            })
            .collect::<contract::Result<Vec<R>>>()
    }
}

#[cfg(feature = "signing")]
mod contract_signing {
    use super::*;
    use crate::{api::Accounts, signing, types::TransactionParameters};

    impl<T: Transport> Contract<T> {
        /// Execute a signed contract function and wait for confirmations
        pub async fn signed_call_with_confirmations(
            &self,
            func: &str,
            params: impl Tokenize,
            options: Options,
            confirmations: usize,
            key: impl signing::Key,
        ) -> crate::Result<TransactionReceipt> {
            let poll_interval = time::Duration::from_secs(1);

            let fn_data = self
                .abi
                .function(func)
                .and_then(|function| function.encode_input(&params.into_tokens()))
                // TODO [ToDr] SendTransactionWithConfirmation should support custom error type (so that we can return
                // `contract::Error` instead of more generic `Error`.
                .map_err(|err| crate::error::Error::Decoder(format!("{:?}", err)))?;
            let accounts = Accounts::new(self.eth.transport().clone());
            let mut tx = TransactionParameters {
                nonce: options.nonce,
                to: Some(self.address),
                gas_price: options.gas_price,
                data: Bytes(fn_data),
                ..Default::default()
            };
            if let Some(gas) = options.gas {
                tx.gas = gas;
            }
            if let Some(value) = options.value {
                tx.value = value;
            }
            let signed = accounts.sign_transaction(tx, key).await?;
            confirm::send_raw_transaction_with_confirmation(
                self.eth.transport().clone(),
                signed.raw_transaction,
                poll_interval,
                confirmations,
            )
            .await
        }
    }
}
