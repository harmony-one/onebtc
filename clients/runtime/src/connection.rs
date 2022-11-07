use crate::error::{Error, Web3Error};

use hmy_web3::{
    transports::{Either, Http, WebSocket},
    Hmy, HmyNamespace, Web3,
};
use tokio::time::{sleep, timeout};

use std::time::Duration;

pub type Transport = Either<WebSocket, Http>;

const RETRY_TIMEOUT: Duration = Duration::from_millis(1000);

pub(crate) fn new_http_client(url: &str) -> Result<Hmy<Transport>, Error> {
    let transport = Http::new(url)?;
    let transport = Either::Right(transport);
    let http_client = Web3::new(transport);
    Ok(http_client.hmy())
}

pub(crate) async fn new_websocket_client(url: &str) -> Result<Hmy<Transport>, Error> {
    let transport = WebSocket::new(url).await?;
    let transport = Either::Left(transport);
    let ws_client = Web3::new(transport);
    Ok(ws_client.hmy())
}

pub(crate) async fn new_websocket_client_with_retry(
    url: &str,
    connection_timeout: Duration,
) -> Result<Hmy<Transport>, Error> {
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
