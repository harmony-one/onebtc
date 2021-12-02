const { ethers } = require("hardhat");

async function main() {
  const relayAddress = "0x695C5c8159b7d95540f725ca6119d834854F555F";
  const oracleAddress = "0xa43A1B4643B28e11be995a20873495b71F9d5bF7";

  const Relay = await ethers.getContractFactory("RelayMock");
  const relay = await Relay.attach(relayAddress);

  const ExchangeRateOracle = await ethers.getContractFactory(
    "ExchangeRateOracle"
  );
  const oracle = await ExchangeRateOracle.attach(oracleAddress);

  const OneBtc = await ethers.getContractFactory("OneBtc");
  const oneBtc = await upgrades.deployProxy(
    // "0x31D981ADb8598CD6664Fb20e7091DEfAa8474601",
    OneBtc,
    [relay.address, oracle.address],
    { initializer: "initialize" }
  );

  console.log("OneBtc deployed to:", oneBtc.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
