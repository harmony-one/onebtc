const { ethers } = require("hardhat");
const bitcoin = require('bitcoinjs-lib');
const { issueTxMock } = require('../test/mock/btcTxMock');
const bn = b => BigInt(`0x${b.toString('hex')}`);
const Web3 = require("web3");
const web3 = new Web3();

async function main() {
    const ExchangeRateOracle = await ethers.getContractFactory("ExchangeRateOracle");
    const oracle = await ExchangeRateOracle.attach(
        process.env.EXCHANGE_RATE_ORACLE
    );

    // console.log(await oracle.getExchangeRate());
    const collateral = web3.utils.toWei('211587');
    // console.log(await oracle.doFunc());
    console.log(await oracle.collateralToWrapped(collateral))
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });