const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
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
    this.ExchangeRateOracleWrapper = await ExchangeRateOracleWrapper.new();

    this.authorizedOracle = accounts[1];
    this.unauthorizedOracle = accounts[2];
  });

  it("add authorized oracle", async function () {
    await this.ExchangeRateOracleWrapper.addAuthorizedOracle(
      this.authorizedOracle
    );

    let isAuthorizedOracle =
      await this.ExchangeRateOracleWrapper.authorizedOracles(
        this.authorizedOracle
      );
    assert.equal(isAuthorizedOracle, true);
    isAuthorizedOracle = await this.ExchangeRateOracleWrapper.authorizedOracles(
      this.unauthorizedOracle
    );
    assert.equal(isAuthorizedOracle, false);
  });

  it("setExchangeRate, getExchangeRate", async function () {
    // check initial exchange rate
    let exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();
    assert.equal(exchangeRate, 0);

    // set exchange rate to 100
    const req = await this.ExchangeRateOracleWrapper.setExchangeRate(
      this.authorizedOracle,
      100
    );

    // check exchange rate, reverted with `ERR_INVALID_ORACLE_SOURCE` due to the MAX_DELAY limit
    await expectRevert(
      this.ExchangeRateOracleWrapper.getExchangeRate(),
      "ERR_MISSING_EXCHANGE_RATE"
    );

    // increase time
    await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
    await web3.miner.mine();

    // check exchange rate
    exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();
    assert.equal(exchangeRate, 100);
    const event = req.logs.filter((log) => log.event == "SetExchangeRate")[0];
    assert.equal(event.args.oracle, this.authorizedOracle);
    assert.equal(event.args.rate, 100);
  });

  it("Error on setExchange with unauthorizedOracle", async function () {
    await expectRevert(
      this.ExchangeRateOracleWrapper.setExchangeRate(
        this.unauthorizedOracle,
        200
      ),
      "ERR_INVALID_ORACLE_SOURCE"
    );
  });

  it("setSatoshiPerBytes", async function () {
    const req = await this.ExchangeRateOracleWrapper.setSatoshiPerBytes(5, 10, {
      from: this.authorizedOracle,
    });
    const event = req.logs.filter((log) => log.event == "SetSatoshiPerByte")[0];
    assert.equal(event.args.fee, 5);
    assert.equal(event.args.inclusionEstimate, 10);
  });

  it("Error on setSatoshiPerBytes with unauthorizedOracle", async function () {
    await expectRevert(
      this.ExchangeRateOracleWrapper.setSatoshiPerBytes(5, 10, {
        from: this.unauthorizedOracle,
      }),
      "ERR_INVALID_ORACLE_SOURCE"
    );
  });

  it("collateralToWrapped", async function () {
    const amount = 10000;
    const collateralToWrapped =
      await this.ExchangeRateOracleWrapper.collateralToWrapped(amount);

    // increase time and get exchange rate
    await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
    await web3.miner.mine();
    const exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();

    // check collateralToWrapped
    assert.equal(collateralToWrapped, amount / exchangeRate);
  });

  it("wrappedToCollateral", async function () {
    const amount = 10;
    const wrappedToCollateral =
      await this.ExchangeRateOracleWrapper.wrappedToCollateral(amount);

    // increase time and get exchange rate
    await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
    await web3.miner.mine();
    const exchangeRate = await this.ExchangeRateOracleWrapper.getExchangeRate();

    // check collateralToWrapped
    assert.equal(wrappedToCollateral, amount * exchangeRate);
  });
});
