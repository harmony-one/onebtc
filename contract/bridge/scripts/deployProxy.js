const { ethers } = require("hardhat");

async function main() {
    const ExchangeRateOracle = await ethers.getContractFactory("ExchangeRateOracle");
    const oracle = await upgrades.deployProxy(ExchangeRateOracle, [], { initializer: "initialize" });

    console.log("ExchangeRateOracle deployed to:", oracle.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });