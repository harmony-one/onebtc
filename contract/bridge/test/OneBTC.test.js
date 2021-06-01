const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");

const { expectRevert } = require("@openzeppelin/test-helpers");
const bitcoin = require('bitcoinjs-lib');
const { issue_tx_mock } = require('./mock/btcTxMock');
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
        this.vault_id = accounts[1];
        this.issue_requester = accounts[2];
        this.redeem_requester = accounts[3];
        const ecPair = bitcoin.ECPair.makeRandom({compressed:false});
        const script = bitcoin.payments.p2pkh({pubkey:ecPair.publicKey})
        this.redeem_btc_address = '0x'+script.hash.toString('hex');
    });
    it("vault register test", async function() {
        const pubX = bn(this.VaultEcPair.publicKey.slice(1, 33));
        const pubY = bn(this.VaultEcPair.publicKey.slice(33, 65));
        const collateral = web3.utils.toWei('10');
        await this.OneBtc.register_vault(pubX, pubY, {from:this.vault_id, value: collateral});
        const vault = await this.OneBtc.vaults(this.vault_id);
        assert.equal(pubX.toString(), vault.btc_public_key_x.toString());
        assert.equal(pubX.toString(), vault.btc_public_key_x.toString());
        assert.equal(collateral, vault.collateral.toString());
    });
    it("issue test", async function() {
        const IssueAmount = 0.01*1e8;
        const IssueReq = await this.OneBtc.request_issue(IssueAmount, this.vault_id, {from: this.issue_requester, value:IssueAmount});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequest')[0];
        const issue_id = IssueEvent.args.issue_id;
        const btc_address = IssueEvent.args.btc_address;
        const btc_base58 = bitcoin.address.toBase58Check(Buffer.from(btc_address.slice(2), 'hex'), 0);
        const btcTx = issue_tx_mock(issue_id, btc_base58, IssueAmount);
        const btcBlockNumberMock = 1000;
        const btcTxIndexMock = 2;
        const heightAndIndex = btcBlockNumberMock<<32|btcTxIndexMock;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        await this.OneBtc.execute_issue(this.issue_requester, issue_id, proofMock, btcTx.toBuffer(), heightAndIndex, headerMock);
        const OneBtcBalance = await this.OneBtc.balanceOf(this.issue_requester);
        const OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vault_id);
        assert.equal(OneBtcBalance.toString(), IssueEvent.args.amount.toString());
        assert.equal(OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());
    });
    it("redeem test", async function() {
        const RedeemAmount = 0.001*1e8;
        await this.OneBtc.transfer(this.redeem_requester, RedeemAmount, {from: this.issue_requester});
        const RedeemReq = await this.OneBtc.request_redeem(RedeemAmount, this.redeem_btc_address, this.vault_id, {from: this.redeem_requester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequest')[0];
        const redeem_id = RedeemEvent.args.redeem_id;
        
        const btc_amount = RedeemEvent.args.amount;
        const btc_address = RedeemEvent.args.btc_address;
        const btc_base58 = bitcoin.address.toBase58Check(Buffer.from(btc_address.slice(2), 'hex'), 0);
        const btcTx = issue_tx_mock(redeem_id, btc_base58, Number(btc_amount));
        const btcBlockNumberMock  = 1000;
        const btcTxIndexMock = 2;
        const heightAndIndex = btcBlockNumberMock<<32|btcTxIndexMock;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        const exec_redeem = await this.OneBtc.execute_redeem(this.redeem_requester, redeem_id, proofMock, btcTx.toBuffer(), heightAndIndex, headerMock);
        const redeemEvent = exec_redeem.logs.filter(log=>log.event == 'RedeemComplete')[0];
        assert.equal(redeemEvent.args.requester, this.redeem_requester);
    });
    it("cancle issue request test", async function() {
        const IssueAmount = 0.01*1e8;
        const IssueReq = await this.OneBtc.request_issue(IssueAmount, this.vault_id, {from: this.issue_requester, value:IssueAmount});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequest')[0];
        const issue_id = IssueEvent.args.issue_id;
        const request = await this.OneBtc.issueRequests(this.issue_requester, issue_id);
        await expectRevert(this.OneBtc.cancel_issue(this.issue_requester, issue_id), 'TimeNotExpired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancel_issue(this.issue_requester, issue_id);
    });
    it("cancle redeem request test", async function() {
        const RedeemAmount = 0.001*1e8;
        await this.OneBtc.transfer(this.redeem_requester, RedeemAmount, {from: this.issue_requester});
        const RedeemReq = await this.OneBtc.request_redeem(RedeemAmount, this.redeem_btc_address, this.vault_id, {from: this.redeem_requester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequest')[0];
        const redeem_id = RedeemEvent.args.redeem_id;

        const request = await this.OneBtc.redeemRequests(this.redeem_requester, redeem_id);
        
        await expectRevert(this.OneBtc.cancel_redeem(this.redeem_requester, redeem_id), 'TimeNotExpired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancel_redeem(this.redeem_requester, redeem_id);
    });
});