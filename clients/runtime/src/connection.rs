use crate::error::{Error, Web3Error};

use tokio::time::{sleep, timeout};
use web3::{
    transports::{Http, WebSocket},
    Web3,
};

use std::time::Duration;

const RETRY_TIMEOUT: Duration = Duration::from_millis(1000);

pub(crate) fn new_http_client(url: &str) -> Result<Web3<Http>, Error> {
    let transport = Http::new(url)?;
    let http_client = Web3::new(transport);
    Ok(http_client)
}

pub(crate) async fn new_websocket_client(url: &str) -> Result<Web3<WebSocket>, Error> {
    let transport = WebSocket::new(url).await?;
    let ws_client = Web3::new(transport);
    Ok(ws_client)
}

pub(crate) async fn new_websocket_client_with_retry(
    url: &str,
    connection_timeout: Duration,
) -> Result<Web3<WebSocket>, Error> {
    log::info!("Connecting to the btc-bridge...");
    timeout(connection_timeout, async move {
        loop {
            match new_websocket_client(url).await {
                Err(Error::RpcResponseError(Web3Error::Transport(err))) => {
                    log::trace!("could not connect to bridgee: {}", err);
                    sleep(RETRY_TIMEOUT).await;
                    continue;
                }
                Ok(rpc) => {
                    log::info!("Connected!");
                    return Ok(rpc);
                }
                Err(err) => return Err(err),
            }
        }
    })
    .await?
}
