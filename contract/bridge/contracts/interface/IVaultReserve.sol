// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultReserve {
  function withdrawReward(address payable _to, uint256 _amount) external;
}
