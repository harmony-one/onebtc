const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const ExchangeRateOracleWrapper = artifacts.require(
  "ExchangeRateOracleWrapper"
);

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

contract("ExchangeRateOracle unit test", (accounts) => {
  before(async function () {
    this.ExchangeRateOracleWrapper = await deployProxy(
      ExchangeRateOracleWrapper
    );
  });

  it("setExchangeRate, getExchangeRate", async function () {
    // check initial exchange rate
    let exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();
    assert.equal(exchangeRate, 0);

    // set exchange rate to 100
    const req = await this.ExchangeRateOracleWrapper.setExchangeRate(100);

    // check exchange rate, reverted with `ERR_INVALID_ORACLE_SOURCE` due to the MAX_DELAY limit
    await expectRevert(
      this.ExchangeRateOracleWrapper.getExchangeRate(),
      "ERR_MISSING_EXCHANGE_RATE"
    );
    const event = req.logs.filter((log) => log.event == "SetExchangeRate")[0];
    assert.equal(event.args.exchangeRate, 100);

    // increase time
    await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
    await web3.miner.mine();

    // check exchange rate
    exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();
    assert.equal(exchangeRate, 100);
  });

  it("collateralToWrapped", async function () {
    const amount = new BN("1000000000000000000"); // 1e18
    const collateralToWrapped =
      await this.ExchangeRateOracleWrapper.collateralToWrapped(amount);

    // check collateralToWrapped
    const exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();
    const expectedWrapped = amount.div(exchangeRate).div(new BN("10000000000"));
    assert.equal(collateralToWrapped.toString(), expectedWrapped.toString());
  });

  it("wrappedToCollateral", async function () {
    const amount = new BN("100000000"); // 1e8
    const wrappedToCollateral =
      await this.ExchangeRateOracleWrapper.wrappedToCollateral(amount);

    // check collateralToWrapped
    const exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();
    const expectedCollateral = amount
      .mul(exchangeRate)
      .mul(new BN("10000000000"));
    assert.equal(wrappedToCollateral.toString(), expectedCollateral.toString());
  });
});
