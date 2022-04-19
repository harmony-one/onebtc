const { ethers } = require("hardhat");

async function main() {
    // deploy VaultReward contract
    const VaultReward = await ethers.getContractFactory("VaultReward");
    const vaultReward = await upgrades.deployProxy(VaultReward, [process.env.ONE_BTC, process.env.VAULT_RESERVE], { initializer: "initialize" });

    console.log("VaultReward deployed to:", vaultReward.address);

    // Set VaultReward address to OneBtc
    const OneBtc = await ethers.getContractFactory("OneBtc");
    const oneBtc = await OneBtc.attach(
        process.env.ONE_BTC
    );
    await oneBtc.setVaultRewardAddress(vaultReward.address);

    console.log('VaultReward contract address is set on OneBtc');

    // Set VaultReward address to VaultReserve
    const VaultReserve = await ethers.getContractFactory("VaultReserve");
    const vaultReserve = await VaultReserve.attach(
        process.env.VAULT_RESERVE
    );
    await vaultReserve.setVaultReward(vaultReward.address)

    console.log('VaultReward contract address is set on VaultReserve');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
