const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const OneBtc = artifacts.require("OneBtc");
const VaultReserve = artifacts.require("VaultReserve");
const VaultReward = artifacts.require("VaultReward");

module.exports = async function(deployer) {
    const IOneBtc = await OneBtc.deployed();
    const IVaultReserve = await VaultReserve.deployed();

    const c = await deployProxy(VaultReward, [IOneBtc.address, IVaultReserve.address], { deployer } );
    console.log('VaultReward deployed at ', c.address)
};
