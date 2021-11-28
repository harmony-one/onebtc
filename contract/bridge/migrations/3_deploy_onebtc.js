const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");

module.exports = async function(deployer) {
  const IRelay = await RelayMock.deployed();
  const IExchangeRateOracleWrapper = await ExchangeRateOracleWrapper.deployed();

  const c = await deployProxy(OneBtc, [IRelay.address, IExchangeRateOracleWrapper.address], { deployer } );
  console.log(c.address)
};
