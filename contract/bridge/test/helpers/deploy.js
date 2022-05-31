
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const Secp256k1 = artifacts.require("Secp256k1");
const TxValidate = artifacts.require("TxValidate");
const VaultRegistry = artifacts.require("VaultRegistryLib");
const VaultReserve = artifacts.require("VaultReserve");
const VaultReward = artifacts.require("VaultReward");

async function deployOneBTC() {
    const relayMock = await RelayMock.new();
    const exchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);

    const Secp256k1Lib = await Secp256k1.new();
    OneBtc.link("Secp256k1", Secp256k1Lib.address);

    const TxValidateLib = await TxValidate.new();
    OneBtc.link("TxValidate", TxValidateLib.address);

    const VaultRegistryLib = await VaultRegistry.new();
    OneBtc.link("VaultRegistryLib", VaultRegistryLib.address);

    const oneBtc = await deployProxy(OneBtc, [RelayMock.address, ExchangeRateOracleWrapper.address],{unsafeAllowLinkedLibraries: true});
    const vaultReserve = await deployProxy(VaultReserve, []);
    const vaultReward = await deployProxy(VaultReward, [oneBtc.address, vaultReserve.address]);

    // set VaultReward contract address to OneBtc contract
    await oneBtc.setVaultRewardAddress(vaultReward.address);

    // set VaultReward contract address to VaultReserve contract
    await vaultReserve.setVaultReward(vaultReward.address);

    return {oneBtc, relayMock, exchangeRateOracleWrapper}
}

async function printVault(contract, vaultId) {
    const vaultInfo = await contract.vaults(vaultId);
    for(var k in vaultInfo) {
        isNaN(k) && console.log(k, vaultInfo[k].toString())
    }
}

module.exports = {
    deployOneBTC,
    printVault
}