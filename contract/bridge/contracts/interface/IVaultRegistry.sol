// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultRegistry {
  function getVault(address) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256);
}
