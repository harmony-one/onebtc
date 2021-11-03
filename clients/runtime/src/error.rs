pub use hmy_web3::error::Error as Web3Error;
use thiserror::Error;
use tokio::time::error::Elapsed;

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
    /// invalid output type requested by the caller
    #[error("Invalid output type")]
    InvalidOutputType(String),
}
