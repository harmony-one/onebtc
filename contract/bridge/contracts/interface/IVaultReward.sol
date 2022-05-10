// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultReward {
  function updateVaultAccClaimableRewards(address _vaultId) external;

  function getVaultLockExpireAt(address _vaultId) external view returns (uint256);

  function increaseVaultCollateralDebt(address _vaultId, address _staker, uint256 _amount) external;

  function decreaseVaultCollateralDebt(address _vaultId, address _staker, uint256 _amount) external;

  function updateVaultStaker(address _vaultId, address _staker, uint256 _amount) external;

  function getVaultCollateralDebt(address _vaultId) external view returns (uint256);

  function getVaultStakerBalance(address _vaultId, address _staker) external view returns (uint256);

  function increaseVaultStakerBalance(address _vaultId, address _staker, uint256 _amount) external;

  function decreaseVaultStakerBalance(address _vaultId, address _staker, uint256 _amount) external;
}
