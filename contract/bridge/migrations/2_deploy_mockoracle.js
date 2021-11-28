const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");

module.exports = async function(deployer) {
    await deployer.deploy(ExchangeRateOracleWrapper);
};
