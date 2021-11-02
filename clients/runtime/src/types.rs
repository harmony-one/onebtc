use web3::types::{Address, U256};

use std::collections::HashMap;

pub struct OneBtcVault {
    /// first 32-bytes of btc public key
    pub btc_public_key_x: U256,
    /// last 32-bytes of btc public key
    pub btc_public_key_y: U256,
    /// Collateral
    pub collateral: U256,
    /// Amount of issued onebtc
    pub issued: U256,
    /// Amount to be issued
    pub to_be_issued: U256,
    /// Amount to be redeemed
    pub to_be_redeemed: U256,
    /// Replaced collateral
    pub replace_collateral: U256,
    /// Amount to be replaced
    pub to_be_replaced: U256,
    /// Amount of collateral liquidated
    pub liquidated_collateral: U256,
    /// addresses deposited btc
    pub deposit_addresses: HashMap<Address, bool>,
}
