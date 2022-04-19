// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultReserve {
  function withdrawReward(uint256 _amount) external;
}
