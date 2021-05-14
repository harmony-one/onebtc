const TxUtils = artifacts.require("TransactionUtilsMock");
const TxValidate = artifacts.require("TxValidateMock");

const bitcoin = require('bitcoinjs-lib');
const { expectRevert } = require("@openzeppelin/test-helpers");
const { issue_tx_mock } = require('./mock/btcTxMock');

contract("transaction parse test", accounts => {
    it("extractTx and validate_txout", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiver_address = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const request_id = 123;
        const request_amount = 2.5e8;
        const tx_mock = issue_tx_mock(request_id, receiver_address, request_amount);
        const parsed_tx = await txUtils.extractTx(tx_mock.toBuffer());
        const receiver_address_hex = '0x'+bitcoin.address.fromBase58Check(receiver_address).hash.toString('hex');
        const amount = await txValidate.validate_transaction(parsed_tx.vouts, request_amount, receiver_address_hex, request_id);
        assert.equal(Number(amount), request_amount);
    });
    it("validate_txout with wrong request_id", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiver_address = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const request_id = 123;
        const request_amount = 2.5e8;
        const tx_mock = issue_tx_mock(request_id, receiver_address, request_amount);
        const parsed_tx = await txUtils.extractTx(tx_mock.toBuffer());
        const receiver_address_hex = '0x'+bitcoin.address.fromBase58Check(receiver_address).hash.toString('hex');
        await expectRevert(txValidate.validate_transaction(parsed_tx.vouts, request_amount, receiver_address_hex, request_id+1), "InvalidOpReturn");
    });
    it("validate_txout with less amount", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiver_address = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const request_id = 123;
        const request_amount = 2.5e8;
        const tx_mock = issue_tx_mock(request_id, receiver_address, request_amount-1);
        const parsed_tx = await txUtils.extractTx(tx_mock.toBuffer());
        const receiver_address_hex = '0x'+bitcoin.address.fromBase58Check(receiver_address).hash.toString('hex');
        await expectRevert(txValidate.validate_transaction(parsed_tx.vouts, request_amount, receiver_address_hex, request_id), "InsufficientValue");
    });
    it("validate_txout with more amount", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiver_address = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const request_id = 123;
        const request_amount = 2.5e8;
        const tx_mock = issue_tx_mock(request_id, receiver_address, request_amount+10);
        const parsed_tx = await txUtils.extractTx(tx_mock.toBuffer());
        const receiver_address_hex = '0x'+bitcoin.address.fromBase58Check(receiver_address).hash.toString('hex');
        const amount = await txValidate.validate_transaction(parsed_tx.vouts, request_amount, receiver_address_hex, request_id);
        assert.equal(Number(amount), request_amount+10);
    });
    it("validate_txout with wrong receiver", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiver_address = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const request_id = 123;
        const request_amount = 2.5e8;
        const tx_mock = issue_tx_mock(request_id, receiver_address, request_amount+10);
        const parsed_tx = await txUtils.extractTx(tx_mock.toBuffer());
        const receiver_address_hex = '0x1111111111111111111111111111111111111111';
        await expectRevert(txValidate.validate_transaction(parsed_tx.vouts, request_amount, receiver_address_hex, request_id), "InvalidRecipient");
    });
    it("validate_txout without request_id", async () => {
        const txUtils = await TxUtils.new();
        const txValidate = await TxValidate.new();
        const receiver_address = '12L1QTVLowqsRUNht35RyBE3RZzmCZzYF3';
        const request_id = 123;
        const request_amount = 2.5e8;
        const tx_mock = issue_tx_mock(undefined, receiver_address, request_amount+10);
        const parsed_tx = await txUtils.extractTx(tx_mock.toBuffer());
        const receiver_address_hex = '0x'+bitcoin.address.fromBase58Check(receiver_address).hash.toString('hex');
        await expectRevert(txValidate.validate_transaction(parsed_tx.vouts, request_amount, receiver_address_hex, request_id), "NoOpRetrun");
    });
});