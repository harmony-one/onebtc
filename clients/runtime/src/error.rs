use thiserror::Error;
use tokio::time::error::Elapsed;
pub use web3::error::Error as Web3Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Harmony chanin error")]
    HarmonyError,
    #[error("Request has timed out")]
    Timeout,
    #[error("Web3 response error")]
    RpcResponseError(#[from] Web3Error),
    #[error("Timeout: {0}")]
    TimeElapsed(#[from] Elapsed),
}

impl Error {}
