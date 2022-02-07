const TxUtils = artifacts.require("TransactionUtilsMock");
const TxValidate = artifacts.require("TxValidateMock");

const bitcoin = require('bitcoinjs-lib');
const { expectRevert } = require("@openzeppelin/test-helpers");
const { issueTxMock } = require('./mock/btcTxMock');

contract("transaction parse test", accounts => {
    it("extractTx and validateTxout", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiverAddress = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const requestId = 123;
        const outputIndex = 0;
        const requestAmount = 2.5e8;
        const txMock = issueTxMock(requestId, receiverAddress, requestAmount);
        const parsedTx = await txUtils.extractTx(txMock.toBuffer());
        const receiverAddressHex = '0x'+bitcoin.address.fromBase58Check(receiverAddress).hash.toString('hex');
        const amount = await txValidate.validateTransaction(parsedTx.vouts, requestAmount, receiverAddressHex, requestId, outputIndex);
        assert.equal(Number(amount), requestAmount);
    });
    it("validateTxout with wrong requestId", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiverAddress = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const requestId = 123;
        const outputIndex = 0;
        const requestAmount = 2.5e8;
        const txMock = issueTxMock(requestId, receiverAddress, requestAmount);
        const parsedTx = await txUtils.extractTx(txMock.toBuffer());
        const receiverAddressHex = '0x'+bitcoin.address.fromBase58Check(receiverAddress).hash.toString('hex');
        await expectRevert(txValidate.validateTransaction(parsedTx.vouts, requestAmount, receiverAddressHex, requestId+1, outputIndex), "Invalid OpReturn");
    });
    it("validateTxout with less amount", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiverAddress = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const requestId = 123;
        const outputIndex = 0;
        const requestAmount = 2.5e8;
        const txMock = issueTxMock(requestId, receiverAddress, requestAmount-1);
        const parsedTx = await txUtils.extractTx(txMock.toBuffer());
        const receiverAddressHex = '0x'+bitcoin.address.fromBase58Check(receiverAddress).hash.toString('hex');
        await expectRevert(txValidate.validateTransaction(parsedTx.vouts, requestAmount, receiverAddressHex, requestId, outputIndex), "Insufficient BTC value");
    });
    it("validateTxout with more amount", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiverAddress = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const requestId = 123;
        const outputIndex = 0;
        const requestAmount = 2.5e8;
        const txMock = issueTxMock(requestId, receiverAddress, requestAmount+10);
        const parsedTx = await txUtils.extractTx(txMock.toBuffer());
        const receiverAddressHex = '0x'+bitcoin.address.fromBase58Check(receiverAddress).hash.toString('hex');
        const amount = await txValidate.validateTransaction(parsedTx.vouts, requestAmount, receiverAddressHex, requestId, outputIndex);
        assert.equal(Number(amount), requestAmount+10);
    });
    it("validateTxout with wrong receiver", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiverAddress = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const requestId = 0;
        const outputIndex = 0;
        const requestAmount = 2.5e8;
        const txMock = issueTxMock(requestId, receiverAddress, requestAmount+10);
        const parsedTx = await txUtils.extractTx(txMock.toBuffer());
        const receiverAddressHex = '0x1111111111111111111111111111111111111111';
        await expectRevert(txValidate.validateTransaction(parsedTx.vouts, requestAmount, receiverAddressHex, requestId, outputIndex), "Invalid recipient");
    });
    it("validateTxout without requestId", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiverAddress = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const requestId = 123;
        const outputIndex = 0;
        const requestAmount = 2.5e8;
        const txMock = issueTxMock(undefined, receiverAddress, requestAmount+10);
        const parsedTx = await txUtils.extractTx(txMock.toBuffer());
        const receiverAddressHex = '0x'+bitcoin.address.fromBase58Check(receiverAddress).hash.toString('hex');
        await expectRevert(txValidate.validateTransaction(parsedTx.vouts, requestAmount, receiverAddressHex, requestId, outputIndex), "Invalid OpReturn");
    });
});