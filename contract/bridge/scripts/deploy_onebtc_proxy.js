const { ethers } = require("hardhat");

async function main() {
    const Relay = await ethers.getContractFactory("RelayMock");
    const relay = await Relay.attach(
        process.env.HMY_RELAY_CONTRACT
    );

    const ExchangeRateOracle = await ethers.getContractFactory("ExchangeRateOracle");
    const oracle = await ExchangeRateOracle.attach(
        process.env.EXCHANGE_RATE_ORACLE
    );

    const OneBtc = await ethers.getContractFactory("OneBtc");
    const oneBtc = await upgrades.deployProxy(OneBtc, [relay.address, oracle.address], { initializer: "initialize" });

    console.log("OneBtc deployed to:", oneBtc.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
