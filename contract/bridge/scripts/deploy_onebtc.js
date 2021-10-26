const { ethers } = require("hardhat");

async function main() {
    const RelayMock = await ethers.getContractFactory("RelayMock");
    const relayMock = await RelayMock.deploy();

    console.log("RelayMock deployed to:", relayMock.address);

    const OneBtc = await ethers.getContractFactory("OneBtc");
    const oneBtc = await OneBtc.deploy();
    await oneBtc.initialize(relayMock.address);

    console.log("OneBtc deployed to:", oneBtc.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });