const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");

module.exports = async function(deployer) {
  const IRelay = await RelayMock.deployed();
  deployer.deploy(OneBtc, IRelay.address);
};
