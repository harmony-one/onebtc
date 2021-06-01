// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ICollateral} from "./Collateral.sol";
import {BitcoinKeyDerivation} from "./crypto/BitcoinKeyDerivation.sol";

abstract contract VaultRegistry is ICollateral {
    struct Vault {
        uint256 btc_public_key_x;
        uint256 btc_public_key_y;
        uint256 collateral;
        address[] deposit_addresses;
    }
    mapping(address => Vault) public vaults;

    event RegisterVault(
        address indexed vault_id,
        uint256 collateral,
        uint256 btc_public_key_x,
        uint256 btc_public_key_y
    );

    event VaultPublicKeyUpdate(address indexed vault_id, uint256 x, uint256 y);

    function register_vault(uint256 btc_public_key_x, uint256 btc_public_key_y)
        external
        payable
    {
        address vault_id = msg.sender;
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x == 0, "vaultExist");
        require(
            btc_public_key_x != 0 && btc_public_key_y != 0,
            "invalidPubkey"
        );
        vault.btc_public_key_x = btc_public_key_x;
        vault.btc_public_key_y = btc_public_key_y;
        lock_additional_collateral();
        emit RegisterVault(
            vault_id,
            msg.value,
            btc_public_key_x,
            btc_public_key_y
        );
    }

    function _register_deposit_address(address vault_id, uint256 issue_id)
        internal
        returns (address)
    {
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        address derivedKey =
            BitcoinKeyDerivation.derivate(
                vault.btc_public_key_x,
                vault.btc_public_key_y,
                issue_id
            );
        vault.deposit_addresses.push(derivedKey);
        return derivedKey;
    }

    function update_public_key(
        uint256 btc_public_key_x,
        uint256 btc_public_key_y
    ) external {
        address vault_id = msg.sender;
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        vault.btc_public_key_x = btc_public_key_x;
        vault.btc_public_key_y = btc_public_key_y;
        emit VaultPublicKeyUpdate(vault_id, btc_public_key_x, btc_public_key_y);
    }

    function lock_additional_collateral() public payable {
        address vault_id = msg.sender;
        Vault storage vault = vaults[vault_id];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        vault.collateral += msg.value;
        ICollateral.lock_collateral(vault_id, msg.value);
    }

    function withdraw_collateral(uint256 amount) external {
        Vault storage vault = vaults[msg.sender];
        require(vault.btc_public_key_x != 0, "vaultNotExist");
        vault.collateral -= amount;
        ICollateral.release_collateral(msg.sender, amount);
    }

    function try_increase_to_be_issued_tokens(address vault_id, uint256 amount) internal {
        //Vault storage vault = vaults[vault_id];
        //uint256 newIssued = vault.issued_btc + amount;
    }
}
