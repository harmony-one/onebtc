// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./interface/IVaultRegistry.sol";
import "./interface/IVaultReserve.sol";

contract VaultReward is Initializable {
  using SafeMathUpgradeable for uint256;

  struct LockedVault {
    uint256 lockStartAt;
    uint256 lockPeriod;
    uint256 lockExpireAt;
    uint256 rewardClaimAt;
    uint256 accClaimableRewards;
    uint256 accRewardPerShare;
    uint256 accRewardPerSharelUpdatedAt;
    uint256 collateralDebt;
  }

  struct VaultStaker {
    uint256 balance;
    uint256 accClaimableRewards;
    uint256 rewardDebt;
  }

  address public oneBtc;
  address public vaultReserve;
  mapping(address => LockedVault) public lockedVaults;  // Vault -> LockedVault
  mapping(address => mapping(address => VaultStaker)) public vaultStakers;  // Vault -> User -> VaultStaker
  mapping(address => address[]) public userStakedVaultList;  // User -> Vault list

  event ExtendVaultLockPeriod(address indexed vaultId, uint256 oldLockPeriod, uint256 newLockPeriod);
  event ClaimRewards(address indexed vaultId, uint256 amount, uint256 claimAt);
  event ClaimRewardsAndLock(address indexed vaultId, uint256 amount, uint256 claimAt);
  event UpdateVaultAccClaimableRewards(
    address indexed vaultId,
    uint256 oldAccClaimableRewards,
    uint256 newAccClaimableRewards,
    uint256 updatedAt
  );

  modifier vaultExist(address _vaultId) {
    (uint256 btcPublicKeyX,,,,,,,,) = IVaultRegistry(oneBtc).getVault(_vaultId);
    require(btcPublicKeyX != 0, "Vault does not exist");
    _;
  }

  receive() external payable {}

  function initialize(address _oneBtc, address _vaultReserve) public initializer {
    oneBtc = _oneBtc;
    vaultReserve = _vaultReserve;
  }

  function extendVaultLockPeriod(address _vaultId, uint256 _lockPeriod) external vaultExist(_vaultId) {
    require(_vaultId == msg.sender, "Invalid vaultId");

    // check if the lockPeriod is valid
    require(_lockPeriod == 3 || _lockPeriod == 6 || _lockPeriod == 12, "Lock period should be one of 3, 6, 12");

    // update vault accClaimableRewards
    updateVaultAccClaimableRewards(_vaultId);

    // get vault
    LockedVault storage vault = lockedVaults[_vaultId];

    // get the current vault lock period
    uint256 oldLockPeriod = vault.lockPeriod;

    // update the vault lock info
    uint256 secPerDay = 60 * 60 * 24;
    uint256 lockPeriodInSec = secPerDay.mul(30).mul(_lockPeriod);
    if (vault.lockExpireAt < block.timestamp) {   // new or expired vault
      vault.lockStartAt = block.timestamp;
      vault.lockPeriod = _lockPeriod;
      vault.lockExpireAt = block.timestamp.add(lockPeriodInSec);
      vault.rewardClaimAt = block.timestamp;
      vault.accClaimableRewards = 0;
      vault.accRewardPerShare = 0;
      vault.accRewardPerSharelUpdatedAt = block.timestamp;
      vault.collateralDebt = 0;
    } else {    // locked vault
      vault.lockPeriod = vault.lockPeriod.add(_lockPeriod);
      vault.lockExpireAt = vault.lockExpireAt.add(lockPeriodInSec);
    }

    emit ExtendVaultLockPeriod(_vaultId, oldLockPeriod, vault.lockPeriod);
  }

  function updateVaultAccClaimableRewards(address _vaultId) public {
    if (block.timestamp <= lockedVaults[_vaultId].lockExpireAt) {
      // get vault
      LockedVault storage vault = lockedVaults[_vaultId];

      // store the old accClaimableRewards
      uint256 oldAccClaimableRewards = vault.accClaimableRewards;

      // update the vault info
      (uint256 claimableRewards, uint256 rewardClaimAt) = getClaimableRewards(_vaultId);
      vault.accClaimableRewards = claimableRewards;
      vault.rewardClaimAt = rewardClaimAt;

      emit UpdateVaultAccClaimableRewards(_vaultId, oldAccClaimableRewards, vault.accClaimableRewards, rewardClaimAt);
    }
  }

  function claimRewards(address payable _vaultId) external {
    require(_vaultId == msg.sender, "Invalid vaultId");

    // claiim rewards
    (uint256 claimableRewards, uint256 rewardClaimAt) = _claimRewards(_vaultId, _vaultId);

    emit ClaimRewards(_vaultId, claimableRewards, rewardClaimAt);
  }

  function claimRewardsAndLock(address payable _vaultId) external {
    require(_vaultId == msg.sender, "Invalid vaultId");

    // claim rewards
    (uint256 claimableRewards, uint256 rewardClaimAt) = _claimRewards(_vaultId, address(this));

    // lock collateral
    IVaultRegistry(oneBtc).lockAdditionalCollateralFromVaultReward{value: claimableRewards}(_vaultId);

    emit ClaimRewardsAndLock(_vaultId, claimableRewards, rewardClaimAt);
  }

  function _claimRewards(address _vaultId, address payable _to) internal returns(uint256, uint256) {
    // get reward debt
    (uint256 claimableRewards, uint256 rewardClaimAt) = getClaimableRewards(_vaultId);
    
    // update the vault info
    LockedVault storage vault = lockedVaults[_vaultId];
    vault.accClaimableRewards = 0;
    vault.rewardClaimAt = rewardClaimAt;

    // transfer rewards
    IVaultReserve(vaultReserve).withdrawReward(_to, claimableRewards);

    return (claimableRewards, rewardClaimAt);
  }

  function getClaimableRewards(address _vaultId) public view vaultExist(_vaultId) returns (uint256 claimableRewards, uint256 rewardClaimAt) {
    // get vault collateral
    (,, uint256 collateral,,,,,, uint256 liquidatedCollateral) = IVaultRegistry(oneBtc).getVault(_vaultId);
    uint256 vaultUsedCollateral = collateral.sub(liquidatedCollateral);

    // get vault
    LockedVault memory vault = lockedVaults[_vaultId];

    // get APR based on the lock period
    uint256 lockPeriod = vault.lockPeriod;
    uint256 vaultAPR;
    if (lockPeriod == 3) {
      vaultAPR = 5;
    } else if (lockPeriod >= 6) {
      vaultAPR = 10;
    } else if (lockPeriod >= 12) {
      vaultAPR = 15;
    }

    // get the elapsed time
    uint256 secPerDay = 60 * 60 * 24;
    uint256 elapsedSecs;
    if (block.timestamp <= vault.lockExpireAt) {
      rewardClaimAt = block.timestamp.sub(
        (block.timestamp.sub(vault.rewardClaimAt)) //elapsed seconds since the last claim
        .mod(secPerDay.mul(14)) // mod by 2 weeks to get remaining seconds in this 2 week period
      );  //timestamp of last applicable 2 week period for rewards
      elapsedSecs = rewardClaimAt.sub(vault.rewardClaimAt); //end result is a amount in seconds that is a multiple of 2 weeks, and represent the number of 2 week periods since last claim
    } else {
      rewardClaimAt = vault.lockExpireAt;
      elapsedSecs = rewardClaimAt.sub(vault.rewardClaimAt);
    }

    // calculate the remaining rewards since the last claim time
    uint256 claimableUnit = elapsedSecs.div(secPerDay).div(14); // claim every 14 days
    if (claimableUnit == 0) {
      claimableRewards = vault.accClaimableRewards;
    } else {
      claimableRewards = vault.accClaimableRewards.add(vaultUsedCollateral.mul(claimableUnit).mul(14).mul(vaultAPR).div(36500));
    }
  }

  function getVaultLockExpireAt(address _vaultId) external view returns (uint256) {
    return lockedVaults[_vaultId].lockExpireAt;
  }
}
