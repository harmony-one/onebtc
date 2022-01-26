// scripts/upgrade-box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
    const ExchangeRateOracleV2 = await ethers.getContractFactory("ExchangeRateOracleV2");
    const oracle2 = await upgrades.upgradeProxy(process.env.EXCHANGE_RATE_ORACLE, ExchangeRateOracleV2);
    console.log("oracle upgraded");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });