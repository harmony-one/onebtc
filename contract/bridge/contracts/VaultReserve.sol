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

  event Deposit(address indexed by, uint256 value);
  event Withdraw(address indexed by, address indexed to, uint256 value);
  event EmergencyWithdraw(address indexed by, address indexed to, uint256 value);

  modifier onlyVaultReward() {
    require(msg.sender == vaultReward, "only VaultReward");
    _;
  }

  receive() external payable {
    totalDepositAmount = totalDepositAmount.add(msg.value);

    emit Deposit(msg.sender, msg.value);
  }

  function initialize() external {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();
  }

  function depositReward() public payable {
    totalDepositAmount = totalDepositAmount.add(msg.value);

    emit Deposit(msg.sender, msg.value);
  }

  function withdrawReward(address payable _to, uint256 _amount) external onlyVaultReward nonReentrant whenNotPaused {
    totalWithdrawalAmount = totalWithdrawalAmount.add(_amount);

    // transfer rewards
    (bool sent,) = payable(_to).call{value: _amount}("");
    require(sent, "Failed to send ONE");

    emit Withdraw(msg.sender, _to, _amount);
  }

  function emergencyWithdraw(address payable _to, uint256 _amount) external onlyOwner {
    totalWithdrawalAmount = totalWithdrawalAmount.add(_amount);

    // transfer rewards
    (bool sent,) = _to.call{value: _amount}("");
    require(sent, "Failed to send ONE");

    emit EmergencyWithdraw(msg.sender, _to, _amount);
  }

  function getReserveAmount() external view returns (uint256) {
    return totalDepositAmount.sub(totalWithdrawalAmount);
  }

  function setVaultReward(address _vaultReward) external onlyOwner {
    vaultReward = _vaultReward;
  }
}
