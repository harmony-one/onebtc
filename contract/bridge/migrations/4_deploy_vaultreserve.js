const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const VaultReserve = artifacts.require("VaultReserve");

module.exports = async function(deployer) {
    const c = await deployProxy(VaultReserve, [], { deployer } );
    console.log('VaultReserve deployed at ', c.address)
};
