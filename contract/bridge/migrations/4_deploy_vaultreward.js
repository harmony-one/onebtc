const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const OneBtc = artifacts.require("OneBtc");
const VaultReward = artifacts.require("VaultReward");

module.exports = async function(deployer) {
    const IOneBtc = await OneBtc.deployed();

    const c = await deployProxy(VaultReward, [IOneBtc.address], { deployer } );
    console.log('VaultReward contract address = ', c.address)
};
