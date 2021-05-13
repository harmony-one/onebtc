const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");

module.exports = async function(deployer) {
  const IRelay = await RelayMock.deployed();
  await deployer.deploy(OneBtc, IRelay.address);
  const c = await OneBtc.deployed();
  console.log(c.address)
};
