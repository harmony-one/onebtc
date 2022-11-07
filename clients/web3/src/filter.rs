//! `Hmy` namespace, filters.

use futures::{stream, Stream, TryStreamExt};
use futures_timer::Delay;
use jsonrpc_core as rpc;
use serde::de::DeserializeOwned;
use std::{fmt, marker::PhantomData, time::Duration, vec};
use web3::{
    api::Namespace,
    error, helpers,
    types::{Filter, Log, H256},
    Transport,
};

fn filter_stream<T: Transport, I: DeserializeOwned>(
    base: BaseFilter<T, I>,
    poll_interval: Duration,
) -> impl Stream<Item = error::Result<I>> {
    let id = helpers::serialize(&base.id);
    stream::unfold((base, id), move |state| async move {
        let (base, id) = state;
        Delay::new(poll_interval).await;
        let response = base
            .transport
            .execute("hmy_getFilterChanges", vec![id.clone()])
            .await;
        let items: error::Result<Option<Vec<I>>> = response.and_then(helpers::decode);
        let items = items.map(Option::unwrap_or_default);
        Some((items, (base, id)))
    })
    // map I to Result<I> even though it is always Ok so that try_flatten works
    .map_ok(|items| stream::iter(items.into_iter().map(Ok)))
    .try_flatten()
    .into_stream()
}

/// Specifies filter items and constructor method.
trait FilterInterface {
    /// Filter item type
    type Output;

    /// Name of method used to construct the filter
    fn constructor() -> &'static str;
}

/// Logs Filter
#[derive(Debug)]
struct LogsFilter;

impl FilterInterface for LogsFilter {
    type Output = Log;

    fn constructor() -> &'static str {
        "hmy_newFilter"
    }
}

/// New blocks hashes filter.
#[derive(Debug)]
struct BlocksFilter;

impl FilterInterface for BlocksFilter {
    type Output = H256;

    fn constructor() -> &'static str {
        "hmy_newBlockFilter"
    }
}

/// New Pending Transactions Filter
#[derive(Debug)]
struct PendingTransactionsFilter;

impl FilterInterface for PendingTransactionsFilter {
    type Output = H256;

    fn constructor() -> &'static str {
        "hmy_newPendingTransactionFilter"
    }
}

/// Base filter handle.
/// Uninstall filter on drop.
/// Allows to poll the filter.
pub struct BaseFilter<T: Transport, I> {
    // TODO [ToDr] Workaround for ganache returning 0x03 instead of 0x3
    id: String,
    transport: T,
    item: PhantomData<I>,
}

impl<T: Transport, I: 'static> fmt::Debug for BaseFilter<T, I> {
    fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
        fmt.debug_struct("BaseFilter")
            .field("id", &self.id)
            .field("transport", &self.transport)
            .field("item", &std::any::TypeId::of::<I>())
            .finish()
    }
}

impl<T: Transport, I> Clone for BaseFilter<T, I> {
    fn clone(&self) -> Self {
        BaseFilter {
            id: self.id.clone(),
            transport: self.transport.clone(),
            item: PhantomData::default(),
        }
    }
}

impl<T: Transport, I: DeserializeOwned> BaseFilter<T, I> {
    /// Polls this filter for changes.
    /// Will return logs that happened after previous poll.
    pub async fn poll(&self) -> error::Result<Option<Vec<I>>> {
        let id = helpers::serialize(&self.id);
        let response = self
            .transport
            .execute("hmy_getFilterChanges", vec![id])
            .await?;
        helpers::decode(response)
    }

    /// Returns the stream of items which automatically polls the server
    pub fn stream(self, poll_interval: Duration) -> impl Stream<Item = error::Result<I>> {
        filter_stream(self, poll_interval)
    }
}

impl<T: Transport> BaseFilter<T, Log> {
    /// Returns future with all logs matching given filter
    pub async fn logs(&self) -> error::Result<Vec<Log>> {
        let id = helpers::serialize(&self.id);
        let response = self
            .transport
            .execute("hmy_getFilterLogs", vec![id])
            .await?;
        helpers::decode(response)
    }
}

/// Should be used to create new filter future
async fn create_filter<T: Transport, F: FilterInterface>(
    transport: T,
    arg: Vec<rpc::Value>,
) -> error::Result<BaseFilter<T, F::Output>> {
    let response = transport.execute(F::constructor(), arg).await?;
    let id = helpers::decode(response)?;
    Ok(BaseFilter {
        id,
        transport,
        item: PhantomData,
    })
}

/// `Hmy` namespace, filters
#[derive(Debug, Clone)]
pub struct HmyFilter<T> {
    transport: T,
}

impl<T: Transport> Namespace<T> for HmyFilter<T> {
    fn new(transport: T) -> Self
    where
        Self: Sized,
    {
        HmyFilter { transport }
    }

    fn transport(&self) -> &T {
        &self.transport
    }
}

impl<T: Transport> HmyFilter<T> {
    /// Installs a new logs filter.
    pub async fn create_logs_filter(self, filter: Filter) -> error::Result<BaseFilter<T, Log>> {
        let f = helpers::serialize(&filter);
        create_filter::<_, LogsFilter>(self.transport, vec![f]).await
    }

    /// Installs a new block filter.
    pub async fn create_blocks_filter(self) -> error::Result<BaseFilter<T, H256>> {
        create_filter::<_, BlocksFilter>(self.transport, vec![]).await
    }

    /// Installs a new pending transactions filter.
    pub async fn create_pending_transactions_filter(self) -> error::Result<BaseFilter<T, H256>> {
        create_filter::<_, PendingTransactionsFilter>(self.transport, vec![]).await
    }
}
