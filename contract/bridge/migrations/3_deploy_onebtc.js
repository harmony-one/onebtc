const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");

module.exports = async function(deployer) {
    const IRelay = await RelayMock.deployed();
    const c = await deployProxy(OneBtc, [IRelay.address], { deployer } );
    console.log(c.address)
};
