// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "./IVaultRegistry.sol";

abstract contract VaultReward is Initializable {
  using SafeMathUpgradeable for uint256;

  struct LockedVault {
    uint256 lockStartAt;
    uint256 lockPeriod;
    uint256 lockExpireAt;
    uint256 rewardClaimAt;
    uint256 collateralUpdatedAt;
    uint256 accClaimableRewards;
  }

  address public oneBtc;
  mapping(address => LockedVault) public lockedVaults;

  event ClaimRewards(address indexed vaultId, uint256 amount, uint256 claimAt);
  event UpdateVaultAccClaimableRewards(
      address indexed vaultId,
      uint256 oldAccClaimableRewards,
      uint256 newAccClaimableRewards,
      uint256 updatedAt
  );

  modifier onlyOneBtc() {
    require(msg.sender == oneBtc, "Only OneBtc");
    _;
  }

  modifier vaultExist(address _vaultId) {
    (uint256 btcPublicKeyX,,,,,,,,) = IVaultRegistry(oneBtc).getVault(_vaultId);
    require(btcPublicKeyX != 0, "Vault does not exist");
    _;
  }

  function initialize(address _oneBtc) public initializer {
    oneBtc = _oneBtc;
  }

  function extendVaultLockPeriod(address _vaultId, uint256 _lockPeriod) external vaultExist(_vaultId) {
    // check if the lockPeriod is valid
    require(_lockPeriod == 3 || _lockPeriod == 6 || _lockPeriod == 12, "Lock period should be one of 3, 6, 12");

    // // check if the vault exists
    // require(vaults[_vaultId].btcPublicKeyX == 0, "Vault already exist");

    // update vault accClaimableRewards
    _updateVaultAccClaimableRewards(_vaultId);

    // get vault
    LockedVault storage vault = lockedVaults[_vaultId];

    // update the vault lock info
    uint256 secPerDay = 60 * 60 * 24;
    uint256 lockPeriodInSec = secPerDay.mul(30).mul(_lockPeriod);
    if (vault.lockExpireAt < block.timestamp) {   // new or expired vault
      vault.lockStartAt = block.timestamp;
      vault.lockPeriod = _lockPeriod;
      vault.lockExpireAt = block.timestamp.add(lockPeriodInSec);
      vault.rewardClaimAt = block.timestamp;
      vault.collateralUpdatedAt = block.timestamp;
      vault.accClaimableRewards = 0;
    } else {    // locked vault
      vault.lockPeriod = vault.lockPeriod.add(_lockPeriod);
      vault.lockExpireAt = vault.lockExpireAt.add(lockPeriodInSec);
    }
  }

  function _updateVaultAccClaimableRewards(address _vaultId) internal {
    if (block.timestamp <= lockedVaults[_vaultId].lockExpireAt) {
      // get vault
      LockedVault storage vault = lockedVaults[_vaultId];

      // store the old accClaimableRewards
      uint256 oldAccClaimableRewards = vault.accClaimableRewards;

      // update the vault info
      (uint256 claimableRewards, uint256 rewardClaimAt) = _getAccClaimableRewards(_vaultId);
      vault.accClaimableRewards = vault.accClaimableRewards.add(claimableRewards);
      vault.rewardClaimAt = rewardClaimAt;

      emit UpdateVaultAccClaimableRewards(_vaultId, oldAccClaimableRewards, vault.accClaimableRewards, rewardClaimAt);
    }
  }

  function updateVaultAccClaimableRewards(address _vaultId) external onlyOneBtc {
    if (block.timestamp <= lockedVaults[_vaultId].lockExpireAt) {
      // get vault
      LockedVault storage vault = lockedVaults[_vaultId];

      // store the old accClaimableRewards
      uint256 oldAccClaimableRewards = vault.accClaimableRewards;

      // update the vault info
      (uint256 claimableRewards, uint256 rewardClaimAt) = _getAccClaimableRewards(_vaultId);
      vault.accClaimableRewards = vault.accClaimableRewards.add(claimableRewards);
      vault.rewardClaimAt = rewardClaimAt;

      emit UpdateVaultAccClaimableRewards(_vaultId, oldAccClaimableRewards, vault.accClaimableRewards, rewardClaimAt);
    }
  }

  function _getAccClaimableRewards(address _vaultId) internal vaultExist(_vaultId) returns (uint256 claimableRewards, uint256 rewardClaimAt) {
      // // check if the vault exists
      // require(vaults[_vaultId].btcPublicKeyX != 0, "Vault does not exist");

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
      rewardClaimAt = block.timestamp.sub(mod(block.timestamp.sub(vault.rewardClaimAt), secPerDay.mul(15)));
      uint256 elapsedSecs = rewardClaimAt.sub(vault.rewardClaimAt);

      // calculate the remaining rewards since the last claim time
      uint256 claimableUnit = elapsedSecs.div(secPerDay); // daily claim
      if (claimableUnit == 0) {
          claimableRewards = 0;
      } else {
          claimableRewards = vault.accClaimableRewards.add(vaultUsedCollateral.mul(claimableUnit).mul(vaultAPR).div(36500));
      }
  }

  function claimRewards(address _vaultId) external {
      // get reward debt
      (uint256 claimableRewards, uint256 rewardClaimAt) = getClaimableRewards(_vaultId);
      
      // update the vault info
      LockedVault storage vault = lockedVaults[_vaultId];
      vault.accClaimableRewards = 0;
      vault.rewardClaimAt = rewardClaimAt;

      // transfer rewards
      (bool sent,) = msg.sender.call{value: claimableRewards}("");
      require(sent, "Failed to send ONE");

      emit ClaimRewards(_vaultId, claimableRewards, rewardClaimAt);
  }

  function getClaimableRewards(address _vaultId) public vaultExist(_vaultId) returns (uint256 claimableRewards, uint256 rewardClaimAt) {
      // // check if the vault exists
      // require(vaults[_vaultId].btcPublicKeyX != 0, "Vault does not exist");
      
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
          rewardClaimAt = block.timestamp.sub(mod(block.timestamp.sub(vault.rewardClaimAt), secPerDay.mul(15)));
          elapsedSecs = rewardClaimAt.sub(vault.rewardClaimAt);
      } else {
          rewardClaimAt = vault.lockExpireAt;
          elapsedSecs = rewardClaimAt.sub(vault.rewardClaimAt);
      }

      // calculate the remaining rewards since the last claim time
      uint256 claimableUnit = elapsedSecs.div(secPerDay).div(15); // allow bi-weekly claim
      if (claimableUnit == 0) {
          claimableRewards = 0;
      } else {
          claimableRewards = vault.accClaimableRewards.add(vaultUsedCollateral.mul(claimableUnit).mul(15).mul(vaultAPR).div(36500));
      }
  }

  function mod(uint256 a, uint256 b) private pure returns (uint256 remainder) {
      remainder = a.sub(a.div(b).mul(b));
  }
}
