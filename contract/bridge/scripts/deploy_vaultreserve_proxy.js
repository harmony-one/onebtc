const { ethers } = require("hardhat");

async function main() {
    // deploy VaultReserve contract
    const VaultReserve = await ethers.getContractFactory("VaultReserve");
    const vaultReserve = await upgrades.deployProxy(VaultReserve, [], { initializer: "initialize" });

    console.log("VaultReserve deployed to:", vaultReserve.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
