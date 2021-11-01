const { ethers } = require("hardhat");
const Web3 = require("web3");
const web3 = new Web3();

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