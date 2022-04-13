const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
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
    this.RelayMock = await RelayMock.new();
    this.ExchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);
    this.OneBtc = await deployProxy(OneBtc, [this.RelayMock.address, this.ExchangeRateOracleWrapper.address]);
    this.VaultReward = await deployProxy(VaultReward, [this.OneBtc.address]);

    // set VaultReward contract address to OneBtc contract
    await this.OneBtc.setVaultRewardAddress(this.VaultReward.address);

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
    await web3.miner.incTime(Number(3600 * 24 * 15)); // 15 day
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
    let accClaimableRewardsExpectation = vaultUsedCollateral * 5 * 15 / 365 / 100;  // lockPeriod: 3 months, APR: 5%
    
    // check vault info
    assert.equal(Number(lockStartAt), Number(oldLockStartAt));
    assert.equal(Number(lockPeriod), Number(oldLockPeriod) + Number(vaultLockPeriod))
    assert.equal(Number(lockExpireAt), Number(oldLockExpireAt) + (60*60*24*30*vaultLockPeriod));
    assert.closeTo(Number(rewardClaimAt), currentTimestamp, 1);
    assert.equal(Number(collateralUpdatedAt), oldCollateralUpdatedAt);
    assert.equal(accClaimableRewards, accClaimableRewardsExpectation);
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
    let claimableRewardsExpectation = Number(accClaimableRewards) + (vaultUsedCollateral * 10 * 15 / 365 / 100);  // lockPeriod: 6 months, APR: 10%, accRewards: for 15 days, not 20 days
    let currentTimestamp = await getBlockTimestamp(vault);
    let rewardClaimAtExpectation = Number(currentTimestamp) - (60*60*24*5);
    
    // check vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getClaimableRewards(this.vaultId);
    assert.equal(Number(claimableRewards), claimableRewardsExpectation);
    assert.closeTo(Number(claimAt), rewardClaimAtExpectation, 1);
  });

  it("updateVaultAccClaimableRewards on collateral change", async function() {
    // get vault info
    const { lockStartAt, lockPeriod, lockExpireAt, rewardClaimAt, collateralUpdatedAt, accClaimableRewards } = await this.VaultReward.lockedVaults(this.vaultId);

    const vault = await this.OneBtc.getVault(this.vaultId);
    let vaultUsedCollateral = Number(vault[2]) - Number(vault[8]);
    
    // increase time
    await web3.miner.incTime(Number(3600 * 24 * 20)); // 20 day
    await web3.miner.mine();
    
    // withdraw vault collateral
    let withdrawAmount = web3.utils.toWei("5");
    let tx = await this.OneBtc.withdrawCollateral(withdrawAmount, { from: this.vaultId });
    
    // get expectations
    let claimableRewardsExpectation = Number(accClaimableRewards) + (vaultUsedCollateral * 10 * 30 / 365 / 100);  // lockPeriod: 6 months, APR: 10%, accRewards: for 30 days, not 40(20+20) days
    let currentTimestamp = await getBlockTimestamp(tx);
    let rewardClaimAtExpectation = Number(currentTimestamp) - (60*60*24*10);
    
    // check vault claimable rewards
    const {claimableRewards, rewardClaimAt: claimAt} = await this.VaultReward.getClaimableRewards(this.vaultId);
    assert.equal(Number(claimableRewards), claimableRewardsExpectation);
    assert.closeTo(Number(claimAt), rewardClaimAtExpectation, 1);
  });
});
