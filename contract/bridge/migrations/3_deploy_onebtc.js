const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const Secp256k1 = artifacts.require("Secp256k1");
const TxValidate = artifacts.require("TxValidate");
const VaultRegistry = artifacts.require("VaultRegistryLib");

module.exports = async function(deployer) {
    
    const IRelay = await RelayMock.deployed();
    const IExchangeRateOracleWrapper = await ExchangeRateOracleWrapper.deployed();
    // const Secp256k1Lib = await deployer.deploy(Secp256k1);
    // OneBtc.link("Secp256k1", Secp256k1Lib.address);

    const TxValidateLib = await deployer.deploy(TxValidate);
    OneBtc.link("TxValidate", TxValidateLib.address);

    const VaultRegistryLib = await deployer.deploy(VaultRegistry);
    OneBtc.link("VaultRegistryLib", VaultRegistryLib.address);

    const c = await deployProxy(OneBtc, [IRelay.address, IExchangeRateOracleWrapper.address], 
                                    { deployer, unsafeAllowLinkedLibraries: true } );
    console.log(c.address)
};
