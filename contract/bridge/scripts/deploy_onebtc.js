require("dotenv").config();
const { ethers } = require("hardhat");

async function main() {
    const Relay = await ethers.getContractFactory("RelayMock");
    const relay = await Relay.attach(
        process.env.HMY_RELAY_CONTRACT
    );

    const BtcLib = await ethers.getContractFactory("Secp256k1");
    const btcLib = await BtcLib.deploy();
    const OneBtc = await ethers.getContractFactory("OneBtc", {libraries: {"Secp256k1": btcLib.address}});
    const oneBtc = await OneBtc.deploy();
    await oneBtc.initialize(relay.address);

    console.log("OneBtc deployed to:", oneBtc.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });