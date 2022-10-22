const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const OneBtc = artifacts.require("OneBtc");
const VaultRegistryLib = artifacts.require("VaultRegistryLib");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const VaultReserve = artifacts.require("VaultReserve");
const VaultReward = artifacts.require("VaultReward");

const bitcoin = require("bitcoinjs-lib");
const { assertion } = require("@openzeppelin/test-helpers/src/expectRevert");
const { current } = require("@openzeppelin/test-helpers/src/balance");
const bn = (b) => BigInt(`0x${b.toString("hex")}`);

web3.extend({
  property: "miner",
  methods: [
    {
      name: "incTime",
      call: "evm_increaseTime",
      params: 1,
    },
    {
      name: "mine",
      call: "evm_mine",
      params: 0,
    },
  ],
});

async function getBlockTimestamp(tx) {
  let blockNumber = await web3.eth.getBlockNumber();

  return (await web3.eth.getBlock(blockNumber)).timestamp;
}

contract("VaultReward unit test", (accounts) => {
  before(async function () {
    const deployer = accounts[0];

    this.RelayMock = await RelayMock.new();
    this.ExchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);

    this.VaultRegistryLib = await VaultRegistryLib.new();
    await deployer.link(this.VaultRegistryLib, OneBtc);

    this.OneBtc = await deployProxy(OneBtc, [this.RelayMock.address, this.ExchangeRateOracleWrapper.address], { unsafeAllowLinkedLibraries: true } );
    this.VaultReserve = await deployProxy(VaultReserve, []);
    this.VaultReward = await deployProxy(VaultReward, [this.OneBtc.address, this.VaultReserve.address]);

    // set VaultReward contract address to OneBtc contract
    await this.OneBtc.setVaultRewardAddress(this.VaultReward.address);

    // set VaultReward contract address to VaultReserve contract
    await this.VaultReserve.setVaultReward(this.VaultReward.address);

    // set BTC/ONE exchange rate
    await this.ExchangeRateOracleWrapper.setExchangeRate(10); // 1 OneBtc = 10 ONE

    // increase time to be enable exchange rate
    await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
    await web3.miner.mine();

    this.vaultId = accounts[1];
    this.staker = accounts[2];

    // register the new vault
    this.VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const pubX = bn(this.VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(this.VaultEcPair.publicKey.slice(33, 65));
    this.initialCollateral = web3.utils.toWei("10");
    const req = await this.OneBtc.registerVault(pubX, pubY, {
      from: this.vaultId,
      value: this.initialCollateral
    });
  });

  it("initialize VaultReward with OneBtc address", async function() {
    let oneBtc = await this.VaultReward.oneBtc();
    assert.equal(oneBtc, this.OneBtc.address);
  });

  it("extendVaultLockPeriod", async function() {
    // set lock period
    let vaultLockPeriod = 3;

    // extend vault lock period
    let tx = await this.VaultReward.extendVaultLockPeriod(this.vaultId, vaultLockPeriod, { from: this.vaultId });
    let currentTimestamp = await getBlockTimestamp(tx);

    // check vault info
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, accClaimableRewards,  accRewardPerShare, accRewardPerShareUpdatedAt, collateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);
    assert.equal(lockStartAt, currentTimestamp);
    assert.equal(lockPeriod, vaultLockPeriod)
    assert.equal(lockExpireAt, currentTimestamp + (60*60*24*30*vaultLockPeriod));
    assert.equal(rewardClaimAt, currentTimestamp);
    assert.equal(accClaimableRewards, 0);
    assert.equal(accRewardPerShare, 0);
    assert.equal(accRewardPerShareUpdatedAt, 0);
    assert.equal(collateralDebt, 0);
  });

  it("Error on withdrawal if the vault lock period is not expired", async function() {
    await expectRevert(this.OneBtc.withdrawCollateralByVault(this.initialCollateral, { from: this.vaultId }), 'Vault lock period is not expired');
  });

  it("Errer on extendVaultLockPeriod with mismatched msg.sender", async function() {
    // set lock period
    let lockPeriod = 9;

    // extend vault lock period
    await expectRevert(this.VaultReward.extendVaultLockPeriod(this.vaultId, lockPeriod), 'Invalid vaultId');
  });

  it("Errer on extendVaultLockPeriod with invalid lock period", async function() {
    // set lock period
    let lockPeriod = 9;

    // extend vault lock period
    await expectRevert(this.VaultReward.extendVaultLockPeriod(this.vaultId, lockPeriod, { from: this.vaultId }), 'Lock period should be one of 3, 6, 12');
  });

  it("stakeAdditionalCollateralToVault", async function() {
    // set the staking amount
    const stakeAmount = web3.utils.toWei("5");

    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultUsedCollateral = Number(vault[2]) - Number(vault[8]);

    // stake
    await this.OneBtc.stakeAdditionalCollateralToVault(this.vaultId, { from: this.staker, value: stakeAmount });

    // get expectations
    let vaultUsedCollateralExpectation = Number(oldVaultUsedCollateral) + Number(stakeAmount);
    const { balance: vaultBalance } = await this.VaultReward.vaultStakers(this.vaultId, this.vaultId);
    const { balance: stakerBalance }  = await this.VaultReward.vaultStakers(this.vaultId, this.staker);
    const { collateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);

    // check vault collateral balance and staker balance
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultUsedCollateral = Number(vault[2]) - Number(vault[8]);
    assert.equal(newVaultUsedCollateral, vaultUsedCollateralExpectation);
    assert.equal(vaultBalance, oldVaultUsedCollateral);
    assert.equal(stakerBalance, stakeAmount);
    assert.equal(Number(stakerBalance), Number(collateralDebt));
  });

  it("Error on staker withdrawal if the vault lock period is not expired", async function() {
    // set the staking amount
    const stakeAmount = web3.utils.toWei("5");

    await expectRevert(this.OneBtc.withdrawCollateralByStaker(this.vaultId, stakeAmount, { from: this.staker }), 'Vault lock period is not expired');
  });

  it("updateVaultAccClaimableRewards on the second extendVaultLockPeriod", async function() {
    // get the current vault info
    const { lockStartAt: oldLockStartAt, lockPeriod: oldLockPeriod, lockExpireAt: oldLockExpireAt, rewardClaimAt: oldRewardClaimAt, accClaimableRewards: oldAccClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 14)); // 14 days
    await web3.miner.mine();

    // set lock period
    let vaultLockPeriod = 3;

    // extend vault lock period
    let tx = await this.VaultReward.extendVaultLockPeriod(this.vaultId, vaultLockPeriod, { from: this.vaultId });
    let currentTimestamp = await getBlockTimestamp(tx);

    // get vault info
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, accClaimableRewards,  accRewardPerShare, accRewardPerShareUpdatedAt, collateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);

    // get expectations
    const vault = await this.OneBtc.getVault(this.vaultId);
    let vaultUsedCollateral = Number(vault[2]) - Number(vault[8]);
    let accClaimableRewardsExpectation = vaultUsedCollateral * 5 * 14 / 365 / 100;  // lockPeriod: 3 months, APR: 5%
    
    // check vault info
    assert.equal(Number(lockStartAt), Number(oldLockStartAt));
    assert.equal(Number(lockPeriod), Number(oldLockPeriod) + Number(vaultLockPeriod))
    assert.equal(Number(lockExpireAt), Number(oldLockExpireAt) + (60*60*24*30*vaultLockPeriod));
    assert.closeTo(Number(rewardClaimAt), currentTimestamp, 1);
    assert.closeTo(Number(accClaimableRewards), accClaimableRewardsExpectation, 10);
  });

  it("getVaultTotalClaimableRewards", async function() {
    // get vault info
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, collateralUpdatedAt, accClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);
    
    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 day
    await web3.miner.mine();
    
    // get expectations
    const vault = await this.OneBtc.getVault(this.vaultId);
    let vaultUsedCollateral = Number(vault[2]) - Number(vault[8]);
    let claimableRewardsExpectation = Number(accClaimableRewards) + (vaultUsedCollateral * 10 * 14 / 365 / 100);  // lockPeriod: 6 months, APR: 10%, accRewards: for 14 days, not 20 days
    let currentTimestamp = await getBlockTimestamp(vault);
    let rewardClaimAtExpectation = Number(currentTimestamp) - (60*60*24*6); // 20-14=6
    
    // check vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getVaultTotalClaimableRewards(this.vaultId);
    assert.equal(Number(claimableRewards), claimableRewardsExpectation);
    assert.closeTo(Number(claimAt), rewardClaimAtExpectation, 1);
  });

  it("getStakerClaimableRewards", async function() {
    // get vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getVaultTotalClaimableRewards(this.vaultId);

    // get staker claimable rewards
    const vaultAccClaimableRewards = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.vaultId);
    const stakerAccClaimableRewards = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.staker);

    // check staker claimable rewards
    assert.equal(Number(vaultAccClaimableRewards), claimableRewards / 3 * 2); // since the storage isn't updated, missing the 2% fee
    assert.equal(Number(stakerAccClaimableRewards), claimableRewards / 3 * 0.98); // 2% fee
  });

  it("updateVaultAccClaimableRewards on collateral change", async function() {
    // get vault info
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, collateralUpdatedAt, accClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);

    let vault = await this.OneBtc.getVault(this.vaultId);
    let vaultUsedCollateral = Number(vault[2]) - Number(vault[8]);
    
    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 days
    await web3.miner.mine();
    
    // lock the additional collateral
    let lockAmount = web3.utils.toWei("5");
    let tx = await this.OneBtc.lockAdditionalCollateral({ from: this.vaultId, value: lockAmount });
    
    // get expectations
    let claimableRewardsExpectation = Number(accClaimableRewards) + (vaultUsedCollateral * 10 * 28 / 365 / 100);  // lockPeriod: 6 months, APR: 10%, accRewards: for 28 days, not 40(20+20) days
    let currentTimestamp = await getBlockTimestamp(tx);
    let rewardClaimAtExpectation = Number(currentTimestamp) - (60*60*24*12);  // 40-28=12
    
    // check vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getVaultTotalClaimableRewards(this.vaultId);
    assert.closeTo(Number(claimableRewards), claimableRewardsExpectation, 10000);
    assert.closeTo(Number(claimAt), rewardClaimAtExpectation, 10);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 days
    await web3.miner.mine();

    // get the current vault collateral amount
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultUsedCollateral = Number(vault[2]) - Number(vault[8]);

    // get expectations
    claimableRewardsExpectation = Number(accClaimableRewards) + (vaultUsedCollateral * 10 * 28 / 365 / 100) + (newVaultUsedCollateral * 10 * 28 / 365 / 100);  // lockPeriod: 6 months, APR: 10%, accRewards: for 56 days (old Collateral:28 days + new collateral: 28 days), not 60(20+20+20) days
    currentTimestamp = await getBlockTimestamp(tx);
    rewardClaimAtExpectation = Number(currentTimestamp) - (60*60*24*4);  // 60-56=4
    
    // check vault claimable rewards
    const {claimableRewards: newClaimableRewards, rewardClaimAt: newClaimAt} = await this.VaultReward.getVaultTotalClaimableRewards(this.vaultId);
    assert.closeTo(Number(newClaimableRewards), claimableRewardsExpectation, 100);
    assert.closeTo(Number(newClaimAt), rewardClaimAtExpectation, 10);
  });

  it("claimVaultRewards", async function() {
    // check old vault balance
    let oldVaultBalance = await web3.eth.getBalance(this.vaultId);
    
    // deposit rewards to VaultReserve contract
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getVaultTotalClaimableRewards(this.vaultId);
    await this.VaultReserve.depositReward({
      from: accounts[0],
      value: Number(claimableRewards) * 2
    });

    // get staker claimable rewards
    const stakerRewardAmount = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.vaultId);

    // claim rewards
    const receipt = await this.VaultReward.claimVaultRewards(this.vaultId, this.vaultId, { from: this.vaultId });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;
    
    // check new vault balance
    let newVaultBalance = await web3.eth.getBalance(this.vaultId);
    assert.closeTo(Number(oldVaultBalance) + Number(stakerRewardAmount) - Number(gas), Number(newVaultBalance), 100000);
  });

  it("claimStakerRewards", async function() {
    // check the old staker balance
    let oldStakerBalance = await web3.eth.getBalance(this.staker);

    // deposit rewards to VaultReserve contract
    const claimableRewards = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.staker);
    await this.VaultReserve.depositReward({
      from: accounts[0],
      value: Number(claimableRewards) * 2
    });

    // claim rewards
    const receipt = await this.VaultReward.claimStakerRewards(this.vaultId, this.staker, { from: this.staker });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;
    
    // check new staker balance
    let newStakerBalance = await web3.eth.getBalance(this.staker);
    assert.closeTo(Number(oldStakerBalance) + Number(claimableRewards) - Number(gas), Number(newStakerBalance), 100000);
  });

  it("claimVaultRewardsAndLock", async function() {
    // get old vault balance
    let oldVaultBalance = await web3.eth.getBalance(this.vaultId);

    // check old vault collateral
    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultCollateral = Number(vault[2]) - Number(vault[8]);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 day
    await web3.miner.mine();

    // deposit rewards to VaultReserve contract
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getVaultTotalClaimableRewards(this.vaultId);
    await this.VaultReserve.depositReward({
      from: accounts[0],
      value: Number(claimableRewards) * 2
    });

    // get staker claimable rewards
    const stakerRewardAmount = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.vaultId);

    // get collateral debt
    const { collateralDebt: oldCollateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);
    
    // claim rewards and lock it again
    const receipt = await this.VaultReward.claimVaultRewardsAndLock(this.vaultId, { from: this.vaultId });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;
    
    // get new vault balance
    let newVaultBalance = await web3.eth.getBalance(this.vaultId);

    // get new vault collateral
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultCollateral = Number(vault[2]) - Number(vault[8]);

    // get new collateral debt
    const { collateralDebt: newCollateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);

    // check new vault balance and collateral
    assert.closeTo(Number(oldVaultBalance) - Number(gas), Number(newVaultBalance), 100000);
    assert.closeTo(Number(oldVaultCollateral) + Number(stakerRewardAmount), Number(newVaultCollateral), 100000);
    assert.equal(Number(newCollateralDebt), Number(oldCollateralDebt));
  });

  it("claimStakerRewardsAndLock", async function() {
    // get old staker balance
    let oldStakerBalance = await web3.eth.getBalance(this.staker);

    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultCollateral = Number(vault[2]) - Number(vault[8]);

    // deposit rewards to VaultReserve contract
    const claimableRewards = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.staker);
    await this.VaultReserve.depositReward({
      from: accounts[0],
      value: Number(claimableRewards) * 2
    });

    // get collateral debt
    const { collateralDebt: oldCollateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);
    
    // claim rewards and lock it again
    const receipt = await this.VaultReward.claimStakerRewardsAndLock(this.vaultId, { from: this.staker });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;
    
    // get new staker balance
    let newStakerBalance = await web3.eth.getBalance(this.staker);

    // get new vault collateral
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultCollateral = Number(vault[2]) - Number(vault[8]);

    // get new collateral debt
    const { collateralDebt: newCollateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);

    // check new vault balance and collateral
    assert.closeTo(Number(oldStakerBalance) - Number(gas), Number(newStakerBalance), 100000);
    assert.closeTo(Number(oldVaultCollateral) + Number(claimableRewards), Number(newVaultCollateral), 100000);
    assert.equal(Number(newCollateralDebt), Number(oldCollateralDebt) + Number(claimableRewards));
  })

  it("withdraw vault collateral if the vault lock period is expired", async function() {
    // get old vault balance
    let oldVaultBalance = await web3.eth.getBalance(this.vaultId);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 30 * 12)); // 1 year
    await web3.miner.mine();

    // get the old vault collateral
    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultTotalCollateral = vault[2].sub(vault[8]);
    let lockedVault = await this.VaultReward.lockedVaults(this.vaultId);
    let vaultCollateralDebt = lockedVault[7];
    let oldVaultCollateral = oldVaultTotalCollateral.sub(vaultCollateralDebt);

    // withdraw a half of the collateral and claimable rewards
    const withdrawAmount = oldVaultCollateral.div(new BN(2))
    const receipt = await this.OneBtc.withdrawCollateralByVault(withdrawAmount, { from: this.vaultId });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;
    
    // get new vault balance
    let newVaultBalance = await web3.eth.getBalance(this.vaultId);

    // get new vault collateral
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultTotalCollateral = vault[2].sub(vault[8]);

    // get new collateral debt
    lockedVault = await this.VaultReward.lockedVaults(this.vaultId);
    let newVaultCollateralDebt = lockedVault[7];

    // check new vault balance and collateral
    assert.closeTo(Number(oldVaultBalance) + Number(withdrawAmount) - Number(gas), Number(newVaultBalance), 100000);
    assert.equal(Number(newVaultTotalCollateral), Number(oldVaultTotalCollateral.sub(withdrawAmount)));
    assert.equal(Number(vaultCollateralDebt), Number(newVaultCollateralDebt));
  });

  it("extendVaultLockPeriod after the vault is expired", async function() {
    // set lock period
    let vaultLockPeriod = 3;

    // get locked vault info
    const { accClaimableRewards: oldAccClaimableRewards, accRewardPerShare: oldAccRewardPerShare, collateralDebt: oldCollateralDebt} = await this.VaultReward.lockedVaults(this.vaultId);

    // extend vault lock period
    let tx = await this.VaultReward.extendVaultLockPeriod(this.vaultId, vaultLockPeriod, { from: this.vaultId });
    let currentTimestamp = await getBlockTimestamp(tx);

    // check vault info
    const vaultStakingReward = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.vaultId);
    let stakerStakingReward = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.staker);
    stakerStakingReward = stakerStakingReward.div(new BN(98)).mul(new BN(100));
    const accClaimableRewardsExpectation = vaultStakingReward.add(stakerStakingReward);
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, accClaimableRewards,  accRewardPerShare, accRewardPerShareUpdatedAt, collateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);
    assert.equal(lockStartAt, currentTimestamp);
    assert.equal(lockPeriod, vaultLockPeriod)
    assert.equal(lockExpireAt, currentTimestamp + (60*60*24*30*vaultLockPeriod));
    assert.equal(rewardClaimAt, currentTimestamp);
    assert.equal(Number(accClaimableRewards), Number(oldAccClaimableRewards));
    assert.closeTo(Number(accClaimableRewards), Number(accClaimableRewardsExpectation), 100);
    assert.equal(Number(accRewardPerShare), Number(oldAccRewardPerShare));
    assert.equal(accRewardPerShareUpdatedAt, 0);
    assert.equal(Number(collateralDebt), Number(oldCollateralDebt));
  })

  it("updateVaultStaker from stakeAdditionalCollateralToVault", async function() {
    // get vault info
    const { accClaimableRewards: oldClaimableRewards, collateralDebt: oldCollateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);

    // get vault collateral
    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultUsedCollateral = Number(vault[2]) - Number(vault[8]);

    // get staker claimable rewards
    const oldVaultRewardAmount = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.vaultId);
    const oldStakerRewardAmount = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.staker);

    // get staker balance
    const oldVaultStakingBalance = (await this.VaultReward.vaultStakers(this.vaultId, this.vaultId))[0];
    const oldStakerStakingBalance = (await this.VaultReward.vaultStakers(this.vaultId, this.staker))[0];

    // stake the collateral to the vault
    const stakeAmount = web3.utils.toWei("5");
    await this.OneBtc.stakeAdditionalCollateralToVault(this.vaultId, { from: this.staker, value: stakeAmount });

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 14)); // 14 days
    await web3.miner.mine();

    // get vault info
    const { collateralDebt: newCollateralDebt } = await this.VaultReward.lockedVaults(this.vaultId);
    const { claimableRewards: newClaimableRewards } = await this.VaultReward.getVaultTotalClaimableRewards(this.vaultId);

    // get vault collateral
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultUsedCollateral = Number(vault[2]) - Number(vault[8]);

    // get staker balance
    const newVaultStakingBalance = (await this.VaultReward.vaultStakers(this.vaultId, this.vaultId))[0];
    const newStakerStakingBalance = (await this.VaultReward.vaultStakers(this.vaultId, this.staker))[0];

    // get staker claimable rewards
    const newVaultRewardAmount = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.vaultId);
    const newStakerRewardAmount = await this.VaultReward.getStakerClaimableRewards(this.vaultId, this.staker);

    // check new newVaultUsedCollateral, vaultAccClaimableRewards and stakerRewardAmount
    let vaultUsedCollateralExpectation = Number(oldVaultUsedCollateral) + Number(stakeAmount);
    let vaultAccClaimableRewardsChange = newVaultUsedCollateral * 5 * 14 / 365 / 100;  // lockPeriod: 3 months, APR: 5%, 14 days
    let vaultAccClaimableRewardsExpectation = Number(oldClaimableRewards) + vaultAccClaimableRewardsChange;
    let vaultRewardAmountExpectation = (Number(oldVaultRewardAmount) + Number(oldStakerRewardAmount) * 2 / 98)  // add 2% fee
      + vaultAccClaimableRewardsChange * Number(newVaultStakingBalance) / (Number(newVaultStakingBalance) + Number(newStakerStakingBalance));
    let stakerRewardAmountExpectation = Number(oldStakerRewardAmount) + vaultAccClaimableRewardsChange * Number(newStakerStakingBalance) * 0.98 / (Number(newVaultStakingBalance) + Number(newStakerStakingBalance));  // 2% fee
    let collateralDebtExpectation = Number(oldCollateralDebt) + Number(stakeAmount);

    assert.equal(newVaultUsedCollateral, vaultUsedCollateralExpectation);
    assert.equal(Number(newClaimableRewards), vaultAccClaimableRewardsExpectation);
    assert.closeTo(Number(newVaultRewardAmount), vaultRewardAmountExpectation, 10000);
    assert.equal(Number(newStakerRewardAmount), stakerRewardAmountExpectation);
    assert.closeTo(Number(newCollateralDebt), collateralDebtExpectation, 10000);
  });

  it("Error on vault collateral withdrawal if the vault lock period is not expired", async function() {
    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 30 * 12)); // 1 year
    await web3.miner.mine();

    // get the old vault collateral
    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultTotalCollateral = vault[2].sub(vault[8]);
    let lockedVault = await this.VaultReward.lockedVaults(this.vaultId);
    let vaultCollateralDebt = lockedVault[7];
    let oldVaultCollateral = oldVaultTotalCollateral.sub(vaultCollateralDebt);

    // withdraw exceeded collateral
    const withdrawAmount = oldVaultCollateral.add(new BN('1'));
    await expectRevert.unspecified(this.OneBtc.withdrawCollateralByVault(withdrawAmount, { from: this.vaultId }));
  });

  it("withdraw all vault collateral if the vault lock period is expired", async function() {
    // get the old vault collateral
    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultTotalCollateral = vault[2].sub(vault[8]);
    let lockedVault = await this.VaultReward.lockedVaults(this.vaultId);
    let oldVaultCollateralDebt = lockedVault[7];
    let oldVaultCollateral = oldVaultTotalCollateral.sub(oldVaultCollateralDebt);

    // withdraw all collateral
    const withdrawAmount = oldVaultCollateral;
    await this.OneBtc.withdrawCollateralByVault(withdrawAmount, { from: this.vaultId });

    // get the new vault info
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultTotalCollateral = vault[2].sub(vault[8]);
    lockedVault = await this.VaultReward.lockedVaults(this.vaultId);
    let newVaultCollateralDebt = lockedVault[7];
    let newVaultCollateral = newVaultTotalCollateral.sub(newVaultCollateralDebt);

    // check vault info
    assert.equal(newVaultCollateral, 0);
    assert.equal(Number(oldVaultCollateralDebt), Number(newVaultCollateralDebt));
    assert.equal(Number(newVaultTotalCollateral), Number(newVaultCollateralDebt));
  });

  it("Error on staker collateral withdrawal if the vault lock period is not expired", async function() {
    // get staker balance
    const { balance: oldStakerBalance }  = await this.VaultReward.vaultStakers(this.vaultId, this.staker);

    // withdraw exceeded collateral
    const withdrawAmount = oldStakerBalance.add(new BN('1'));
    await expectRevert.unspecified(this.OneBtc.withdrawCollateralByStaker(this.vaultId, withdrawAmount, { from: this.staker }));
  });

  it("withdraw all staker collateral if the vault lock period is expired", async function() {
    // get the old vault info
    vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultTotalCollateral = vault[2].sub(vault[8]);

    // get the old staker balance
    const { balance: oldStakerBalance }  = await this.VaultReward.vaultStakers(this.vaultId, this.staker);
    
    // withdraw all collateral
    const withdrawAmount = oldStakerBalance;
    await this.OneBtc.withdrawCollateralByStaker(this.vaultId, oldStakerBalance, { from: this.staker });
    
    // get the new vault info
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultTotalCollateral = vault[2].sub(vault[8]);

    // get the new staker info
    const { balance: newstakerBalance }  = await this.VaultReward.vaultStakers(this.vaultId, this.staker);
    
    assert.equal(Number(oldVaultTotalCollateral), Number(oldStakerBalance));
    assert.equal(newstakerBalance, 0);
    assert.equal(newVaultTotalCollateral, 0);
  });
});