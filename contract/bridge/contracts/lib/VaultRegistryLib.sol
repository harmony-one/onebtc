// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import {BitcoinKeyDerivation} from "../crypto/BitcoinKeyDerivation.sol";
import "../interface/IVaultRegistry.sol";

library VaultRegistryLib {
  function registerVault(IVaultRegistry.Vault storage vault, uint256 btcPublicKeyX, uint256 btcPublicKeyY)
    external
  {
    require(vault.btcPublicKeyX == 0, "Vault already exist");
    require(btcPublicKeyX != 0 && btcPublicKeyY != 0, "Invalid public key");
    vault.btcPublicKeyX = btcPublicKeyX;
    vault.btcPublicKeyY = btcPublicKeyY;
  }

  function registerDepositAddress(IVaultRegistry.Vault storage vault, address vaultId, uint256 issueId)
    external
    returns (address)
  {
    address derivedKey = BitcoinKeyDerivation.derivate(
      vault.btcPublicKeyX,
      vault.btcPublicKeyY,
      issueId
    );

    require(
      !vault.depositAddresses[derivedKey],
      "The btc address is already used"
    );
    vault.depositAddresses[derivedKey] = true;

    return derivedKey;
  }

  function insertVaultDepositAddress(
    IVaultRegistry.Vault storage vault,
    uint256 btcPublicKeyX,
    uint256 btcPublicKeyY,
    uint256 replaceId
  ) external returns (address) {
    address btcAddress = BitcoinKeyDerivation.derivate(
      btcPublicKeyX,
      btcPublicKeyY,
      replaceId
    );

    require(
      !vault.depositAddresses[btcAddress],
      "The btc address is already used"
    );
    vault.depositAddresses[btcAddress] = true;

    return btcAddress;
  }
}
