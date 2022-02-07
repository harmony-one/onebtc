const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const VaultRegistry = artifacts.require("VaultRegistry");
const OneBtc = artifacts.require("OneBtc");

module.exports = async function(deployer) {
  // RelayMock
  const relayMock = await RelayMock.deployed();
  console.log("RelayMock contract deployed to: ", relayMock.address);

  // ExchangeRateOracleWrapper
  const exchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);
  console.log("ExchangeRateOracleWrapper contract deployed to: ", exchangeRateOracleWrapper.address);

  // VaultRegistry
  const vaultRegistry = await deployProxy(VaultRegistry, [exchangeRateOracleWrapper.address]);
  console.log("VaultRegistry contract deployed to: ", vaultRegistry.address);

  // OneBtc
  const oneBtc = await deployProxy(OneBtc, [relayMock.address, exchangeRateOracleWrapper.address, vaultRegistry.address]);
  console.log("OneBtc contract deployed to: ", oneBtc.address);
};
