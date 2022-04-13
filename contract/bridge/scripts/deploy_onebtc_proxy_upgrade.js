const { ethers, upgrades } = require("hardhat");

async function main() {
    const OneBtc = await ethers.getContractFactory("OneBtc");
    const oneBtc = await upgrades.upgradeProxy(process.env.ONE_BTC, OneBtc, { unsafeSkipStorageCheck: true });

    console.log("OneBtc upgraded:", oneBtc.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
