const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const VaultRegistryLib = artifacts.require("VaultRegistryLib");

module.exports = async function(deployer) {
    const IRelay = await RelayMock.deployed();
    const IExchangeRateOracleWrapper = await ExchangeRateOracleWrapper.deployed();
    
    await deployer.deploy(VaultRegistryLib);
    await VaultRegistryLib.deployed();
    await deployer.link(VaultRegistryLib, OneBtc);

    const c = await deployProxy(OneBtc, [IRelay.address, IExchangeRateOracleWrapper.address], { unsafeAllowLinkedLibraries: true, from: deployer } );
    console.log('OneBtc deployed at ', c.address)
};
