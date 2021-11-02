use std::time::Duration;

use crate::{
    bitcoin::PublicKey as BtcPublicKey,
    connection::{new_websocket_client, new_websocket_client_with_retry, Transport},
    web3::Hmy,
    Error,
};

use async_trait::async_trait;
use web3::{
    signing::Key,
    types::{Address, U256},
};

#[derive(Clone)]
pub struct OneBtcBridge {
    rpc_client: Hmy<Transport>,
    account_id: Address,
}

impl OneBtcBridge {
    pub fn new<P: Into<Hmy<Transport>>>(rpc_client: P, signer: impl Key) -> Result<Self, Error> {
        let account_id = signer.address().clone();
        let rpc_client = rpc_client.into();

        Ok(Self {
            rpc_client,
            account_id,
        })
    }

    pub async fn from_url(url: &str, signer: impl Key) -> Result<Self, Error> {
        let ws_client = new_websocket_client(url).await?;
        Self::new(ws_client, signer)
    }

    pub async fn from_url_with_retry(
        url: &str,
        signer: impl Key,
        connection_timout: Duration,
    ) -> Result<Self, Error> {
        let ws_client = new_websocket_client_with_retry(url, connection_timout).await?;
        Self::new(ws_client, signer)
    }
}

#[async_trait]
pub trait VaultRegistry {
    async fn register_vault(
        &self,
        vault_id: &Address,
        collateral: U256,
        btc_pubkey: &BtcPublicKey,
    ) -> Result<(), Error>;

    async fn update_pubkey(
        &self,
        vault_id: &Address,
        btc_pubkey: &BtcPublicKey,
    ) -> Result<(), Error>;

    async fn withdraw_collateral(&self, vault_id: &Address, amount: U256) -> Result<(), Error>;

    async fn get_issuable_tokens(&self, vault_id: &Address) -> Result<U256, Error>;
}
