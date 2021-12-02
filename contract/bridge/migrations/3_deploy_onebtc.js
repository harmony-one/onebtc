const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const OneBtc = artifacts.require("OneBtc");
// const RelayMock = artifacts.require("RelayMock");
// const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");

module.exports = async function(deployer) {
  // const IRelay = await RelayMock.deployed();
  // const IExchangeRateOracleWrapper = await ExchangeRateOracleWrapper.deployed();

  const relayAddress = "0xD38BEc54fA5067890d6B789105C428A1Bc243d42";
  const oracleAddress = "0xEb1dF0baf6a29B5d246Cbf7072e0AA44F266555f";

  const c = await deployProxy(OneBtc, [relayAddress, oracleAddress], { deployer } );
  console.log(c.address)
};
