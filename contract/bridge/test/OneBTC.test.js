const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const VaultRegistry = artifacts.require("VaultRegistry");
const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const { issueTxMock } = require("./mock/btcTxMock");

const bitcoin = require('bitcoinjs-lib');
const bn=b=>BigInt(`0x${b.toString('hex')}`);

web3.extend({
    property: 'miner',
    methods: [{
        name: 'incTime',
        call: 'evm_increaseTime',
        params: 1
    },{
        name: 'mine',
        call: 'evm_mine',
        params: 0
    }]
});

contract("issue/redeem test", accounts => {
    before(async function() {
        // get contracts
        this.RelayMock = await RelayMock.new();
        this.ExchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);
        this.VaultRegistry = await deployProxy(VaultRegistry, [this.ExchangeRateOracleWrapper.address]);
        this.OneBtc = await deployProxy(OneBtc, [this.RelayMock.address, this.ExchangeRateOracleWrapper.address, this.VaultRegistry.address]);

        // set OneBtc address to VaultRegistry
        this.VaultRegistry.updateOneBtcAddress(this.OneBtc.address);

        // set BTC/ONE exchange rate
        await this.ExchangeRateOracleWrapper.setExchangeRate(10); // 1 OneBtc = 10 ONE

        // increase time to be enable exchange rate
        await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
        await web3.miner.mine();
        
        this.VaultEcPair = bitcoin.ECPair.makeRandom({compressed:false});
        this.vaultId = accounts[1];
        this.issueRequester = accounts[2];
        this.redeemRequester = accounts[3];
        const ecPair = bitcoin.ECPair.makeRandom({compressed:false});
        const script = bitcoin.payments.p2pkh({pubkey:ecPair.publicKey})
        this.redeemBtcAddress = '0x'+script.hash.toString('hex');
    });
    it("vault register test", async function() {
        const pubX = bn(this.VaultEcPair.publicKey.slice(1, 33));
        const pubY = bn(this.VaultEcPair.publicKey.slice(33, 65));
        const collateral = web3.utils.toWei('10');
        await this.VaultRegistry.registerVault(pubX, pubY, {from:this.vaultId, value: collateral});
        const vault = await this.VaultRegistry.vaults(this.vaultId);
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(collateral, vault.collateral.toString());
    });
    it("issue test", async function() {
        const IssueAmount = 0.05*1e8;
        const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {from: this.issueRequester, value:IssueAmount});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequested')[0];
        const issueId = IssueEvent.args.issueId;
        const btcAddress = IssueEvent.args.btcAddress;
        const btcBase58 = bitcoin.address.toBase58Check(Buffer.from(btcAddress.slice(2), 'hex'), 0);
        const btcTx = issueTxMock(issueId, btcBase58, IssueAmount);
        const btcBlockNumberMock = 1000;
        const btcTxIndexMock = 2;
        const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        const ouputIndexMock = 0;
        await this.OneBtc.executeIssue(this.issueRequester, issueId, proofMock, btcTx.toBuffer(), heightAndIndex, headerMock, ouputIndexMock);
        const OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
        const OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
        assert.equal(OneBtcBalance.toString(), IssueEvent.args.amount.toString());
        assert.equal(OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());
    });
    it("redeem test", async function() {
        const RedeemAmount = 0.001*1e8;
        await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, {from: this.issueRequester});
        const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {from: this.redeemRequester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequested')[0];
        const redeemId = RedeemEvent.args.redeemId;
        
        const btcAmount = RedeemEvent.args.amount;
        const btcAddress = RedeemEvent.args.btcAddress;
        const btcBase58 = bitcoin.address.toBase58Check(Buffer.from(btcAddress.slice(2), 'hex'), 0);
        const btcTx = issueTxMock(redeemId, btcBase58, Number(btcAmount));
        const btcBlockNumberMock  = 1000;
        const btcTxIndexMock = 2;
        const btcTxHeight = btcBlockNumberMock<<32;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        const execRedeem = await this.OneBtc.executeRedeem(this.redeemRequester, redeemId, proofMock, btcTx.toBuffer(), btcTxHeight, btcTxIndexMock, headerMock);
        const redeemEvent = execRedeem.logs.filter(log=>log.event == 'RedeemCompleted')[0];
        assert.equal(redeemEvent.args.requester, this.redeemRequester);
    });
    it("cancle issue request test", async function() {
        const IssueAmount = 0.01*1e8;
        const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {from: this.issueRequester, value:IssueAmount});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequested')[0];
        const issueId = IssueEvent.args.issueId;
        const request = await this.OneBtc.issueRequests(this.issueRequester, issueId);
        await expectRevert(this.OneBtc.cancelIssue(this.issueRequester, issueId), 'Time not expired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancelIssue(this.issueRequester, issueId);
    });
    it("cancle redeem request test", async function() {
        const RedeemAmount = 0.001*1e8;
        await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, {from: this.issueRequester});
        const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {from: this.redeemRequester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequested')[0];
        const redeemId = RedeemEvent.args.redeemId;

        const request = await this.OneBtc.redeemRequests(this.redeemRequester, redeemId);
        
        await expectRevert(this.OneBtc.cancelRedeem(this.redeemRequester, redeemId), 'Time not expired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancelRedeem(this.redeemRequester, redeemId);
    });
});