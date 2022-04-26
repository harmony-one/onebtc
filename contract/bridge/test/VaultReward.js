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
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, collateralUpdatedAt, accClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);
    assert.equal(lockStartAt, currentTimestamp);
    assert.equal(lockPeriod, vaultLockPeriod)
    assert.equal(lockExpireAt, currentTimestamp + (60*60*24*30*vaultLockPeriod));
    assert.equal(rewardClaimAt, currentTimestamp);
    assert.equal(collateralUpdatedAt, currentTimestamp);
    assert.equal(accClaimableRewards, 0);
  });

  it("Error on withdrawal if the vault lock period is not expired", async function() {
    await expectRevert(this.OneBtc.withdrawCollateral(this.initialCollateral, { from: this.vaultId }), 'Vault lock period is not expired');
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

  it("updateVaultAccClaimableRewards on the second extendVaultLockPeriod", async function() {
    // get the current vault info
    const { lockStartAt: oldLockStartAt, lockPeriod: oldLockPeriod, lockExpireAt: oldLockExpireAt, rewardClaimAt: oldRewardClaimAt, collateralUpdatedAt: oldCollateralUpdatedAt, accClaimableRewards: oldAccClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 14)); // 14 day
    await web3.miner.mine();

    // set lock period
    let vaultLockPeriod = 3;

    // extend vault lock period
    let tx = await this.VaultReward.extendVaultLockPeriod(this.vaultId, vaultLockPeriod, { from: this.vaultId });
    let currentTimestamp = await getBlockTimestamp(tx);

    // get vault info
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, collateralUpdatedAt, accClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);

    // get expectations
    const vault = await this.OneBtc.getVault(this.vaultId);
    let vaultUsedCollateral = Number(vault[2]) - Number(vault[8]);
    let accClaimableRewardsExpectation = vaultUsedCollateral * 5 * 14 / 365 / 100;  // lockPeriod: 3 months, APR: 5%
    
    // check vault info
    assert.equal(Number(lockStartAt), Number(oldLockStartAt));
    assert.equal(Number(lockPeriod), Number(oldLockPeriod) + Number(vaultLockPeriod))
    assert.equal(Number(lockExpireAt), Number(oldLockExpireAt) + (60*60*24*30*vaultLockPeriod));
    assert.closeTo(Number(rewardClaimAt), currentTimestamp, 1);
    assert.equal(Number(collateralUpdatedAt), oldCollateralUpdatedAt);
    assert.closeTo(Number(accClaimableRewards), accClaimableRewardsExpectation, 10);
  });

  it("getClaimableRewards", async function() {
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
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getClaimableRewards(this.vaultId);
    assert.equal(Number(claimableRewards), claimableRewardsExpectation);
    assert.closeTo(Number(claimAt), rewardClaimAtExpectation, 1);
  });

  it("updateVaultAccClaimableRewards on collateral change", async function() {
    // get vault info
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, collateralUpdatedAt, accClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);

    let vault = await this.OneBtc.getVault(this.vaultId);
    let vaultUsedCollateral = Number(vault[2]) - Number(vault[8]);
    
    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 day
    await web3.miner.mine();
    
    // lock the additional collateral
    let lockAmount = web3.utils.toWei("5");
    let tx = await this.OneBtc.lockAdditionalCollateral({ from: this.vaultId, value: lockAmount });
    
    // get expectations
    let claimableRewardsExpectation = Number(accClaimableRewards) + (vaultUsedCollateral * 10 * 28 / 365 / 100);  // lockPeriod: 6 months, APR: 10%, accRewards: for 28 days, not 40(20+20) days
    let currentTimestamp = await getBlockTimestamp(tx);
    let rewardClaimAtExpectation = Number(currentTimestamp) - (60*60*24*12);  // 40-28=12
    
    // check vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getClaimableRewards(this.vaultId);
    assert.equal(Number(claimableRewards), claimableRewardsExpectation);
    assert.closeTo(Number(claimAt), rewardClaimAtExpectation, 1);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 day
    await web3.miner.mine();

    // get the current vault collateral amount
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultUsedCollateral = Number(vault[2]) - Number(vault[8]);

    // get expectations
    claimableRewardsExpectation = Number(accClaimableRewards) + (vaultUsedCollateral * 10 * 28 / 365 / 100) + (newVaultUsedCollateral * 10 * 28 / 365 / 100);  // lockPeriod: 6 months, APR: 10%, accRewards: for 56 days (old Collateral:28 days + new collateral: 28 days), not 60(20+20+20) days
    currentTimestamp = await getBlockTimestamp(tx);
    rewardClaimAtExpectation = Number(currentTimestamp) - (60*60*24*4);  // 60-56=4
    
    // check vault claimable rewards
    const {claimableRewards: newClaimableRewards, rewardClaimAt: newClaimAt} = await this.VaultReward.getClaimableRewards(this.vaultId);
    assert.closeTo(Number(newClaimableRewards), claimableRewardsExpectation, 100);
    assert.closeTo(Number(newClaimAt), rewardClaimAtExpectation, 1);
  });

  it("claimRewards", async function() {
    // check old vault balance
    let oldVaultBalance = await web3.eth.getBalance(this.vaultId);
    
    // get vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getClaimableRewards(this.vaultId);
    
    // deposit rewards to VaultReserve contract
    await this.VaultReserve.depositReward({
      from: accounts[0],
      value: Number(claimableRewards) * 2
    });

    // claim rewards
    const receipt = await this.VaultReward.claimRewards(this.vaultId, { from: this.vaultId });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;

    // check new vault balance
    let newVaultBalance = await web3.eth.getBalance(this.vaultId);
    assert.closeTo(Number(oldVaultBalance) + Number(claimableRewards) - Number(gas), Number(newVaultBalance), 100000);
  });

  it("claimRewardsAndLock", async function() {
    // get old vault balance
    let oldVaultBalance = await web3.eth.getBalance(this.vaultId);

    // check old vault collateral
    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultCollateral = Number(vault[2]) - Number(vault[8]);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 day
    await web3.miner.mine();

    // get vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getClaimableRewards(this.vaultId);

    // deposit rewards to VaultReserve contract
    await this.VaultReserve.depositReward({
      from: accounts[0],
      value: Number(claimableRewards) * 2
    });
    
    // claim rewards and lock it again
    const receipt = await this.VaultReward.claimRewardsAndLock(this.vaultId, { from: this.vaultId });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;
    
    // get new vault balance
    let newVaultBalance = await web3.eth.getBalance(this.vaultId);

    // get new vault collateral
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultCollateral = Number(vault[2]) - Number(vault[8]);

    // check new vault balance and collateral
    assert.closeTo(Number(oldVaultBalance) - Number(gas), Number(newVaultBalance), 100000);
    assert.closeTo(Number(oldVaultCollateral) + Number(claimableRewards), Number(newVaultCollateral), 100000);
  });

  it("withdraw if the vault lock period is expired", async function() {
    // get old vault balance
    let oldVaultBalance = await web3.eth.getBalance(this.vaultId);

    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 30 * 12)); // 1 year
    await web3.miner.mine();

    // check old vault collateral
    let vault = await this.OneBtc.getVault(this.vaultId);
    let oldVaultCollateral = vault[2].sub(vault[8]);

    // withdraw all collateral and claimable rewards
    const receipt = await this.OneBtc.withdrawCollateral(oldVaultCollateral, { from: this.vaultId });
    const gasUsed = receipt.receipt.gasUsed;
    const tx = await web3.eth.getTransaction(receipt.tx);
    const gasPrice = tx.gasPrice;
    const gas = gasPrice * gasUsed;
    
    // get new vault balance
    let newVaultBalance = await web3.eth.getBalance(this.vaultId);

    // get new vault collateral
    vault = await this.OneBtc.getVault(this.vaultId);
    let newVaultCollateral = vault[2].sub(vault[8]);

    // check new vault balance and collateral
    assert.equal(Number(oldVaultBalance) + Number(oldVaultCollateral) - Number(gas), Number(newVaultBalance));
    assert.equal(Number(newVaultCollateral), 0);
  });
});
