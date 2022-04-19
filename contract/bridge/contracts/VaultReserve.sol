// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./interface/IVaultRegistry.sol";

contract VaultReserve is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
  using SafeMathUpgradeable for uint256;

  uint256 public totalDepositAmount;
  uint256 public totalWithdrawalAmount;

  address public vaultReward;

  modifier onlyVaultReward() {
    require(msg.sender == vaultReward, "only VaultReward");
    _;
  }

  modifier checkReserve(uint256 _amount) {
    require(totalDepositAmount.sub(totalWithdrawalAmount) >= _amount, "insufficient reserve");
    _;
  }

  receive() external payable {}

  function initialize() external {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();
  }

  function depositReward() public payable {
    totalDepositAmount = totalDepositAmount.add(msg.value);
  }

  function withdrawReward(uint256 _amount) external onlyVaultReward nonReentrant whenNotPaused checkReserve(_amount) {
    totalWithdrawalAmount = totalWithdrawalAmount.add(_amount);

    // transfer rewards
    (bool sent,) = msg.sender.call{value: _amount}("");
    require(sent, "Failed to send ONE");
  }

  function emergencyWithdraw(address payable _to, uint256 _amount) external onlyOwner checkReserve(_amount) {
    totalWithdrawalAmount = totalWithdrawalAmount.add(_amount);

    // transfer rewards
    (bool sent,) = _to.call{value: _amount}("");
    require(sent, "Failed to send ONE");
  }

  function getReserveAmount() external view returns (uint256) {
    return totalDepositAmount.sub(totalWithdrawalAmount);
  }

  function setVaultReward(address _vaultReward) external onlyOwner {
    vaultReward = _vaultReward;
  }
}
