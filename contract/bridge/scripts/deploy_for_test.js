const { ethers, upgrades } = require("hardhat");

async function main() {
    // deployer
    [deployer] = await ethers.getSigners();
    console.log('deployer address is ', deployer.address);

    const RelayMock = await ethers.getContractFactory("RelayMock");
    const relayMock = await RelayMock.deploy();
    await relayMock.deployed();
    console.log("RelayMock contract deployed to: ", relayMock.address);

    const ExchangeRateOracle = await ethers.getContractFactory("ExchangeRateOracle");
    const exchangeRateOracle = await upgrades.deployProxy(ExchangeRateOracle, [process.env.EXCHANGE_RATE_ORACLE]);
    await exchangeRateOracle.deployed();
    console.log("ExchangeRateOracle contract deployed to: ", exchangeRateOracle.address);

    const VaultRegistry = await ethers.getContractFactory("VaultRegistry");
    const vaultRegistry = await upgrades.deployProxy(VaultRegistry, [exchangeRateOracle.address]);
    await vaultRegistry.deployed();
    console.log("VaultRegistry contract deployed to: ", vaultRegistry.address);

    const OneBtc = await ethers.getContractFactory("OneBtc");
    const oneBtc = await upgrades.deployProxy(OneBtc, [relayMock.address, exchangeRateOracle.address, vaultRegistry.address]);
    await oneBtc.deployed();
    console.log("OneBtc contract deployed to: ", oneBtc.address);


    // const Relay = await ethers.getContractFactory("RelayMock");
    // const relay = await Relay.attach(
    //     process.env.HMY_RELAY_CONTRACT
    // );

    // const ExchangeRateOracle = await ethers.getContractFactory("ExchangeRateOracle");
    // const oracle = await ExchangeRateOracle.attach(
    //     process.env.EXCHANGE_RATE_ORACLE
    // );

    // const OneBtc = await ethers.getContractFactory("OneBtc");
    // const oneBtc = await upgrades.deployProxy(OneBtc, [relay.address, oracle.address], { initializer: "initialize" });

    // console.log("OneBtc deployed to:", oneBtc.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });