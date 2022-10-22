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
    uint256 accClaimableRewards;  // Total reward amount for (vault + all stakers)
    uint256 accRewardPerShare;  // Accumulcated ONEs per share times 1e24
    uint256 accRewardPerShareUpdatedAt; // not used
    uint256 collateralDebt; // Sum of all stakers' (excluding vault itself) collateral
  }

  struct VaultStaker {
    uint256 balance;  // Staker's collateral amount
    uint256 accClaimableRewards;
    uint256 rewardDebt; // Reward debt
    //
    // We do some fancy math here. Basically, any point in time, the amount of ONEs
    // entitled to a user but is pending to be distributed is:
    //
    //   pending reward = (staker.balance * LockedVault.accRewardPerShare) - staker.rewardDebt
    //
    // Whenever a user stakes to a vault by locking his collateral. Here's what happens:
    //   1. The LockedVault's `accRewardPerShare` (and `rewardClaimAt`) gets updated.
    //   2. The pending reward of the staker is added to his `accClaimableRewards`
    //   3. User's `balance` gets updated.
    //   4. User's `rewardDebt` gets updated.
  }

  address public oneBtc;
  address public vaultReserve;
  mapping(address => LockedVault) public lockedVaults;  // Vault -> LockedVault
  mapping(address => mapping(address => VaultStaker)) public vaultStakers;  // Vault -> Staker -> VaultStaker
  mapping(address => address[]) public userStakedVaultList;  // Staker -> Vault list
  // upgrade contract
  uint256 private constant ACC_ONE_PRECISION = 1e24;

  event ExtendVaultLockPeriod(address indexed vaultId, uint256 oldLockPeriod, uint256 newLockPeriod);
  event ClaimRewards(address indexed vaultId, address indexed staker, address indexed to, uint256 amount, uint256 claimAt);
  event ClaimVaultRewardsAndLock(address indexed vaultId, uint256 amount, uint256 claimAt);
  event ClaimStakerRewardsAndLock(address indexed vaultId, address indexed staker, uint256 amount, uint256 claimAt);
  event UpdateVaultAccClaimableRewards(
    address indexed vaultId,
    uint256 oldVaultAccClaimableRewards,
    uint256 newVaultAccClaimableRewards,
    uint256 updateAt
  );
  event VaultCollateralDebtChanged(address indexed vaultId, address indexed staker, uint256 oldCollateralDebt, uint256 newCollateralDebt);

  modifier onlyOneBtc() {
    require(msg.sender == oneBtc, "Only OneBtc");
    _;
  }

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

    // get vault
    LockedVault storage vault = lockedVaults[_vaultId];

    // get the current vault lock period
    uint256 oldLockPeriod = vault.lockPeriod;

    // update the vault lock info
    uint256 secPerDay = 60 * 60 * 24;
    uint256 lockPeriodInSec = secPerDay.mul(30).mul(_lockPeriod);
    if (vault.lockExpireAt == 0) {  // new vault
      // update vault accClaimableRewards
      (,, uint256 collateral,,,,,, uint256 liquidatedCollateral) = IVaultRegistry(oneBtc).getVault(_vaultId);
      uint256 vaultUsedCollateral = collateral.sub(liquidatedCollateral);
      _updateVaultStaker(_vaultId, _vaultId, vaultUsedCollateral, true);

      // update lockedVault info
      vault.lockStartAt = block.timestamp;
      vault.lockPeriod = _lockPeriod;
      vault.lockExpireAt = block.timestamp.add(lockPeriodInSec);
      vault.rewardClaimAt = block.timestamp;
    } else if (vault.lockExpireAt > 0 && vault.lockExpireAt < block.timestamp) {   // expired vault
      _updateVaultStaker(_vaultId, _vaultId, 0, true);

      // update lockedVault info
      vault.lockStartAt = block.timestamp;
      vault.lockPeriod = _lockPeriod;
      vault.lockExpireAt = block.timestamp.add(lockPeriodInSec);
      vault.rewardClaimAt = block.timestamp;
    } else {    // locked vault
      // update accClaimableRewards
      _updateVaultStaker(_vaultId, _vaultId, 0, true);

      // update lockedVault info
      vault.lockPeriod = vault.lockPeriod.add(_lockPeriod);
      vault.lockExpireAt = vault.lockExpireAt.add(lockPeriodInSec);
    }

    emit ExtendVaultLockPeriod(_vaultId, oldLockPeriod, vault.lockPeriod);
  }

  function _updateVaultAccClaimableRewards(address _vaultId) internal returns (uint256 claimableRewards, uint256 rewardClaimAt) {
    // get vault
    LockedVault storage vault = lockedVaults[_vaultId];

    // store the old accClaimableRewards
    uint256 oldVaultAccClaimableRewards = vault.accClaimableRewards;

    // update vaultAccClaimableRewards
    (claimableRewards, rewardClaimAt) = getVaultTotalClaimableRewards(_vaultId);
    vault.accClaimableRewards = claimableRewards;
    vault.rewardClaimAt = rewardClaimAt;

    emit UpdateVaultAccClaimableRewards(_vaultId, oldVaultAccClaimableRewards, vault.accClaimableRewards, rewardClaimAt);
  }

  function claimVaultRewards(address _vaultId, address payable _to) external {
    require(_vaultId == msg.sender, "Only vault owner");

    // update vault staker info
    _updateVaultStaker(_vaultId, _vaultId, 0, true);

    // claim rewards
    _claimRewards(_vaultId, _vaultId, _to);
  }

  function claimStakerRewards(address _vaultId, address payable _to) public {
    require(_vaultId != msg.sender, "claim by vault");

    // update vault staker info
    _updateVaultStaker(_vaultId, msg.sender, 0, true);

    // claim rewards
    _claimRewards(_vaultId, msg.sender, _to);
  }

  function claimStakerRewardsFromAllVaults(address payable _to) external {
    uint256 vaultCount = userStakedVaultList[msg.sender].length;
    require(vaultCount > 0, "no staker");

    for (uint256 i; i < vaultCount; i++) {
      // claim rewards from sigle vault
      claimStakerRewards(payable(userStakedVaultList[msg.sender][i]), _to);
    }
  }

  function claimVaultRewardsAndLock(address _vaultId) external {
    require(_vaultId == msg.sender, "Only vault owner");

    // update vault staker info
    _updateVaultStaker(_vaultId, _vaultId, 0, true);

    // claim rewards
    (uint256 claimableRewards, uint256 claimAt) = _claimRewards(_vaultId, _vaultId, address(this));

    // lock collateral
    IVaultRegistry(oneBtc).lockAdditionalCollateralFromVaultReward{value: claimableRewards}(_vaultId);

    emit ClaimVaultRewardsAndLock(_vaultId, claimableRewards, claimAt);
  }

  function claimStakerRewardsAndLock(address _vaultId) external {
    require(_vaultId != msg.sender, "claim by vault");

    // update vault staker info
    _updateVaultStaker(_vaultId, msg.sender, 0, true);

    // claim rewards
    (uint256 claimableRewards, uint256 claimAt) = _claimRewards(_vaultId, msg.sender, address(this));

    // lock collateral
    IVaultRegistry(oneBtc).stakeAdditionalCollateralFromStakerReward{value: claimableRewards}(_vaultId, msg.sender);

    emit ClaimStakerRewardsAndLock(_vaultId, msg.sender, claimableRewards, claimAt);
  }

  function _claimRewards(address _vaultId, address _staker, address payable _to) internal returns (uint256, uint256) {
    LockedVault storage vault = lockedVaults[_vaultId];
    VaultStaker storage vaultStaker = vaultStakers[_vaultId][_staker];

    // get cliamable rewards
    uint256 claimableRewards = vaultStaker.accClaimableRewards;

    // update LockedVault and VaultStaker info
    vault.accClaimableRewards = vault.accClaimableRewards.sub(claimableRewards);
    vaultStaker.accClaimableRewards = 0;

    // transfer rewards
    IVaultReserve(vaultReserve).withdrawReward(_to, claimableRewards);

    emit ClaimRewards(_vaultId, _staker, _to, claimableRewards, vault.rewardClaimAt);

    return (claimableRewards, vault.rewardClaimAt);
  }

  function getVaultTotalClaimableRewards(address _vaultId) public view vaultExist(_vaultId) returns (uint256 claimableRewards, uint256 rewardClaimAt) {
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
    } else if (lockPeriod >= 6 && lockPeriod < 12) {
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

  function updateVaultStaker(address _vaultId, address _staker, uint256 _amount, bool _isDeposit) external onlyOneBtc {
    _updateVaultStaker(_vaultId, _staker, _amount, _isDeposit);
  }

  function _updateVaultStaker(address _vaultId, address _staker, uint256 _amount, bool _isDeposit) internal {
    LockedVault storage vault = lockedVaults[_vaultId];
    VaultStaker storage vaultStaker = vaultStakers[_vaultId][_staker];

    // store the old vaultAccClaimableRewards
    uint256 oldVaultAccClaimableRewards = vault.accClaimableRewards;

    // update vaultAccClaimableRewards
    (uint256 claimableRewards,) = _updateVaultAccClaimableRewards(_vaultId);

    // update userStakedVaultList
    {
      bool isNewVault = true;
      for (uint256 i; i < userStakedVaultList[_staker].length; i++) {
        // check if vaultId is the new vault
        if (userStakedVaultList[_staker][i] == _vaultId) {
          isNewVault = false;
          break;
        }
      }
      if (isNewVault) {
        // add the new vaultId to userStakedVaultList
        userStakedVaultList[_staker].push(_vaultId);
      }
    }

    // get vault collateral
    (,, uint256 collateral,,,,,, uint256 liquidatedCollateral) = IVaultRegistry(oneBtc).getVault(_vaultId);
    uint256 vaultUsedCollateral = collateral.sub(liquidatedCollateral);

    // update vault accRewardPerShare
    if (vaultUsedCollateral > 0) {
      uint256 vaultClaimableRewardsChange = claimableRewards.sub(oldVaultAccClaimableRewards);
      uint256 rewardPerShare = vaultClaimableRewardsChange.mul(ACC_ONE_PRECISION).div(vaultUsedCollateral);
      vault.accRewardPerShare = vault.accRewardPerShare.add(rewardPerShare);
    }

    // update vaultStakers accClaimableRewards
    if (vaultStaker.balance > 0) {
      uint256 pending = (vaultStaker.balance.mul(vault.accRewardPerShare).div(ACC_ONE_PRECISION)).sub(vaultStaker.rewardDebt);
      if (_vaultId == _staker) {
        vaultStaker.accClaimableRewards = vaultStaker.accClaimableRewards.add(pending); // update vault accClaimableRewards
      } else {
        uint256 feeForVault = pending.mul(2).div(100);  // 2% fee to vault, 98% to staker
        VaultStaker storage vaultSelfStaker = vaultStakers[_vaultId][_vaultId];
        vaultSelfStaker.accClaimableRewards = vaultSelfStaker.accClaimableRewards.add(feeForVault); // update vault accClaimableRewards
        vaultStaker.accClaimableRewards = vaultStaker.accClaimableRewards.add(pending).sub(feeForVault);  // update staker accClaimableRewards
      }
    }

    // update vaultStaker's balance and rewardDebt
    if (_isDeposit) {
      vaultStaker.balance = vaultStaker.balance.add(_amount);
    } else {
      vaultStaker.balance = vaultStaker.balance.sub(_amount);
    }
    vaultStaker.rewardDebt = vault.accRewardPerShare.mul(vaultStaker.balance).div(ACC_ONE_PRECISION);
  }

  function getStakerClaimableRewards(address _vaultId, address _staker) public view vaultExist(_vaultId) returns (uint256 claimableRewards) {
    LockedVault memory vault = lockedVaults[_vaultId];
    VaultStaker memory vaultStaker = vaultStakers[_vaultId][_staker];

    // store the old vaultAccClaimableRewards
    uint256 oldVaultAccClaimableRewards = vault.accClaimableRewards;

    // update vaultAccClaimableRewards
    (uint256 vaultClaimableRewards,) = getVaultTotalClaimableRewards(_vaultId);

    // get vault collateral
    (,, uint256 collateral,,,,,, uint256 liquidatedCollateral) = IVaultRegistry(oneBtc).getVault(_vaultId);
    uint256 vaultUsedCollateral = collateral.sub(liquidatedCollateral);

    // update vault accRewardPerShare
    uint256 vaultAccRewardPerShare;
    if (vaultUsedCollateral > 0) {
      uint256 vaultClaimableRewardsChange = vaultClaimableRewards.sub(oldVaultAccClaimableRewards);
      uint256 rewardPerShare = vaultClaimableRewardsChange.mul(ACC_ONE_PRECISION).div(vaultUsedCollateral);
      vaultAccRewardPerShare = vault.accRewardPerShare.add(rewardPerShare);
    }

    // get vaultStakers accClaimableRewards
    if (vaultStaker.balance > 0) {
      uint256 pending = (vaultStaker.balance.mul(vaultAccRewardPerShare).div(ACC_ONE_PRECISION)).sub(vaultStaker.rewardDebt);
      if (_vaultId == _staker) {
        claimableRewards = vaultStaker.accClaimableRewards.add(pending); // update vault accClaimableRewards
      } else {
        if (_vaultId == _staker) {
          claimableRewards = vaultStaker.accClaimableRewards.add(pending);
        } else {
          uint256 feeForVault = pending.mul(2).div(100);  // 2% fee to vault, 98% to staker
          claimableRewards = vaultStaker.accClaimableRewards.add(pending).sub(feeForVault);  // update staker accClaimableRewards
        }
      }
    }
  }

  function getVaultLockExpireAt(address _vaultId) external view returns (uint256) {
    return lockedVaults[_vaultId].lockExpireAt;
  }

  function increaseVaultCollateralDebt(address _vaultId, address _staker, uint256 _amount) external onlyOneBtc {
    // get the vault
    LockedVault storage vault = lockedVaults[_vaultId];

    // get the old vault collateral debt
    uint256 oldCollateralDebt = vault.collateralDebt;

    // update the vault collatearl debt
    uint256 newCollateralDebt = vault.collateralDebt.add(_amount);
    vault.collateralDebt = newCollateralDebt;
    
    emit VaultCollateralDebtChanged(_vaultId, _staker, oldCollateralDebt, newCollateralDebt);
  }

  function decreaseVaultCollateralDebt(address _vaultId, address _staker, uint256 _amount) external onlyOneBtc {
    // get the vault
    LockedVault storage vault = lockedVaults[_vaultId];

    // get the old vault collateral debt
    uint256 oldCollateralDebt = vault.collateralDebt;

    // update the vault collatearl debt
    uint256 newCollateralDebt = vault.collateralDebt.sub(_amount);
    vault.collateralDebt = newCollateralDebt;
    
    emit VaultCollateralDebtChanged(_vaultId, _staker, oldCollateralDebt, newCollateralDebt);
  }

  function getVaultCollateralDebt(address _vaultId) external view returns (uint256) {
    return lockedVaults[_vaultId].collateralDebt;
  }

  function getVaultStakerBalance(address _vaultId, address _staker) external view returns (uint256) {
    return vaultStakers[_vaultId][_staker].balance;
  }

  function increaseVaultStakerBalance(address _vaultId, address _staker, uint256 _amount) external onlyOneBtc {
    vaultStakers[_vaultId][_staker].balance = vaultStakers[_vaultId][_staker].balance.add(_amount);
  }

  function decreaseVaultStakerBalance(address _vaultId, address _staker, uint256 _amount) external onlyOneBtc {
    vaultStakers[_vaultId][_staker].balance = vaultStakers[_vaultId][_staker].balance.sub(_amount);
  }

  function toUint256(int256 value) internal pure returns (uint256) {
    require(value >= 0, "SafeCast: value must be positive");
    return uint256(value);
  }
}
