const { ethers, upgrades } = require("hardhat");

async function main() {
    const VaultRegistryLib = await ethers.getContractFactory("VaultRegistryLib");
    const vaultRegistryLib = await VaultRegistryLib.deploy();

    console.log('vaultRegistryLib', vaultRegistryLib.address);

    const OneBtc = await ethers.getContractFactory(
        "OneBtc",
        {
            libraries: {
                VaultRegistryLib: vaultRegistryLib.address
            }
        }
    );
    const oneBtc = await upgrades.upgradeProxy(process.env.ONE_BTC, OneBtc, { unsafeSkipStorageCheck: true, unsafeAllowLinkedLibraries: true });

    console.log("OneBtc upgraded:", oneBtc.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
