const RelayMock = artifacts.require("RelayMock");

module.exports = async function(deployer) {
    await deployer.deploy(RelayMock);
};
