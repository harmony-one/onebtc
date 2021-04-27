const RelayMock = artifacts.require("RelayMock");

module.exports = function(deployer) {
    deployer.deploy(RelayMock);
};
