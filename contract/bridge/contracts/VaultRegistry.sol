// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import {ICollateral} from "./Collateral.sol";
import {BitcoinKeyDerivation} from "./crypto/BitcoinKeyDerivation.sol";

abstract contract VaultRegistry is ICollateral {
    struct Vault {
        uint256 btcPublicKeyX;
        uint256 btcPublicKeyY;
        uint256 collateral;
        address[] depositAddresses;
    }
    mapping(address => Vault) public vaults;

    event RegisterVault(
        address indexed vaultId,
        uint256 collateral,
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY
    );

    event VaultPublicKeyUpdate(address indexed vaultId, uint256 x, uint256 y);

    function registerVault(uint256 btcPublicKeyX, uint256 btcPublicKeyY)
        external
        payable
    {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX == 0, "vaultExist");
        require(
            btcPublicKeyX != 0 && btcPublicKeyY != 0,
            "invalidPubkey"
        );
        vault.btcPublicKeyX = btcPublicKeyX;
        vault.btcPublicKeyY = btcPublicKeyY;
        lockAdditionalCollateral();
        emit RegisterVault(
            vaultId,
            msg.value,
            btcPublicKeyX,
            btcPublicKeyY
        );
    }

    function _registerDepositAddress(address vaultId, uint256 issueId)
        internal
        returns (address)
    {
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        address derivedKey =
            BitcoinKeyDerivation.derivate(
                vault.btcPublicKeyX,
                vault.btcPublicKeyY,
                issueId
            );
        vault.depositAddresses.push(derivedKey);
        return derivedKey;
    }

    function updatePublicKey(
        uint256 btcPublicKeyX,
        uint256 btcPublicKeyY
    ) external {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        vault.btcPublicKeyX = btcPublicKeyX;
        vault.btcPublicKeyY = btcPublicKeyY;
        emit VaultPublicKeyUpdate(vaultId, btcPublicKeyX, btcPublicKeyY);
    }

    function lockAdditionalCollateral() public payable {
        address vaultId = msg.sender;
        Vault storage vault = vaults[vaultId];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        vault.collateral += msg.value;
        ICollateral.lockCollateral(vaultId, msg.value);
    }

    function withdrawCollateral(uint256 amount) external {
        Vault storage vault = vaults[msg.sender];
        require(vault.btcPublicKeyX != 0, "vaultNotExist");
        vault.collateral -= amount;
        ICollateral.releaseCollateral(msg.sender, amount);
    }

    function tryIncreaseToBeIssuedTokens(address vaultId, uint256 amount) internal {
        //Vault storage vault = vaults[vaultId];
        //uint256 newIssued = vault.issuedBtc + amount;
    }
}
