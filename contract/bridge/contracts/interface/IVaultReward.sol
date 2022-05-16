// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultReward {
  function updateVaultAccClaimableRewards(address _vaultId) external;

  function getVaultLockExpireAt(address _vaultId) external view returns (uint256);
}
