// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultRegistry {
  struct Vault {
    uint256 btcPublicKeyX;
    uint256 btcPublicKeyY;
    uint256 collateral;
    uint256 issued;
    uint256 toBeIssued;
    uint256 toBeRedeemed;
    uint256 replaceCollateral;
    uint256 toBeReplaced;
    uint256 liquidatedCollateral;
    mapping(address => bool) depositAddresses;
  }

  function getVault(address) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256);

  function lockAdditionalCollateralFromVaultReward(address _vaultId) external payable;
}
