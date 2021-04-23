// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

abstract contract VaultRegistry {
    struct Vault {
        address btc_address;
        bytes btc_public_key;
        uint256 collateral;
    }
    mapping(address=>Vault) public vaults;

    event RegisterVault(address indexed vault_id, address indexed btc_address, uint256 indexed collateral, bytes btc_public_key);

    function register_vault(address btc_address, bytes calldata btc_public_key) external payable {
        address vault_id = msg.sender;
        Vault storage vault = vaults[vault_id];
        require(vault.btc_address == address(0), "vaultExist");
        vault.btc_address = btc_address;
        vault.btc_public_key = btc_public_key;
        vault.collateral = msg.value;
        emit RegisterVault(vault_id, btc_address, vault.collateral, btc_public_key);
    }

    function _register_deposit_address(address vault_id, uint256 /*issue_id*/) internal view returns(address) {
        return vaults[vault_id].btc_address;
    }
    function update_public_key(bytes calldata btc_public_key) external {
        revert("TODO");
    }
    function lock_additional_collateral() external payable {
        Vault storage vault = vaults[msg.sender];
        require(vault.btc_address != address(0), "vaultNotExist");
        vault.collateral += msg.value;
    }
    function withdraw_collateral(uint256 amount) external {
        revert("TODO");
    }
}