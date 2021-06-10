const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");

const { expectRevert } = require("@openzeppelin/test-helpers");
const bitcoin = require('bitcoinjs-lib');
const { issueTxMock } = require('./mock/btcTxMock');
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
        this.name="name";
        const IRelay = await RelayMock.new();
        this.OneBtc = await OneBtc.new(IRelay.address);
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
        await this.OneBtc.registerVault(pubX, pubY, {from:this.vaultId, value: collateral});
        const vault = await this.OneBtc.vaults(this.vaultId);
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(collateral, vault.collateral.toString());
    });
    it("issue test", async function() {
        const IssueAmount = 0.01*1e8;
        const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {from: this.issueRequester, value:IssueAmount});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequest')[0];
        const issueId = IssueEvent.args.issueId;
        const btcAddress = IssueEvent.args.btcAddress;
        const btcBase58 = bitcoin.address.toBase58Check(Buffer.from(btcAddress.slice(2), 'hex'), 0);
        const btcTx = issueTxMock(issueId, btcBase58, IssueAmount);
        const btcBlockNumberMock = 1000;
        const btcTxIndexMock = 2;
        const heightAndIndex = btcBlockNumberMock<<32|btcTxIndexMock;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        await this.OneBtc.executeIssue(this.issueRequester, issueId, proofMock, btcTx.toBuffer(), heightAndIndex, headerMock);
        const OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
        const OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
        assert.equal(OneBtcBalance.toString(), IssueEvent.args.amount.toString());
        assert.equal(OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());
    });
    it("redeem test", async function() {
        const RedeemAmount = 0.001*1e8;
        await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, {from: this.issueRequester});
        const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {from: this.redeemRequester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequest')[0];
        const redeemId = RedeemEvent.args.redeemId;
        
        const btcAmount = RedeemEvent.args.amount;
        const btcAddress = RedeemEvent.args.btcAddress;
        const btcBase58 = bitcoin.address.toBase58Check(Buffer.from(btcAddress.slice(2), 'hex'), 0);
        const btcTx = issueTxMock(redeemId, btcBase58, Number(btcAmount));
        const btcBlockNumberMock  = 1000;
        const btcTxIndexMock = 2;
        const heightAndIndex = btcBlockNumberMock<<32|btcTxIndexMock;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        const execRedeem = await this.OneBtc.executeRedeem(this.redeemRequester, redeemId, proofMock, btcTx.toBuffer(), heightAndIndex, headerMock);
        const redeemEvent = execRedeem.logs.filter(log=>log.event == 'RedeemComplete')[0];
        assert.equal(redeemEvent.args.requester, this.redeemRequester);
    });
    it("cancle issue request test", async function() {
        const IssueAmount = 0.01*1e8;
        const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {from: this.issueRequester, value:IssueAmount});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequest')[0];
        const issueId = IssueEvent.args.issueId;
        const request = await this.OneBtc.issueRequests(this.issueRequester, issueId);
        await expectRevert(this.OneBtc.cancelIssue(this.issueRequester, issueId), 'TimeNotExpired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancelIssue(this.issueRequester, issueId);
    });
    it("cancle redeem request test", async function() {
        const RedeemAmount = 0.001*1e8;
        await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, {from: this.issueRequester});
        const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {from: this.redeemRequester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequest')[0];
        const redeemId = RedeemEvent.args.redeemId;

        const request = await this.OneBtc.redeemRequests(this.redeemRequester, redeemId);
        
        await expectRevert(this.OneBtc.cancelRedeem(this.redeemRequester, redeemId), 'TimeNotExpired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancelRedeem(this.redeemRequester, redeemId);
    });
});