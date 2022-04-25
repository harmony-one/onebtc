
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const Secp256k1 = artifacts.require("Secp256k1");
const TxValidate = artifacts.require("TxValidate");

async function deployOneBTC() {
    const relayMock = await RelayMock.new();
    const exchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);

    const Secp256k1Lib = await Secp256k1.new();
    OneBtc.link("Secp256k1", Secp256k1Lib.address);

    const TxValidateLib = await TxValidate.new();
    OneBtc.link("TxValidate", TxValidateLib.address);

    const oneBtc = await deployProxy(OneBtc, [RelayMock.address, ExchangeRateOracleWrapper.address],{unsafeAllowLinkedLibraries: true});

    return {oneBtc, relayMock, exchangeRateOracleWrapper}
}

module.exports = {
    deployOneBTC
}