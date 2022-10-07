const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const { issueTxMock } = require('./mock/btcTxMock');

const bitcoin = require('bitcoinjs-lib');
const bn=b=>BigInt(`0x${b.toString('hex')}`);

web3.extend({
    property: "miner",
    methods: [
      {
        name: "incTime",
        call: "evm_increaseTime",
        params: 1,
      },
      {
        name: "mine",
        call: "evm_mine",
        params: 0,
      },
    ],
  });

contract("issue/redeem test", accounts => {
    before(async function() {
        this.OneBtc = await OneBtc.deployed()
        this.ExchangeRateOracleWrapper = await ExchangeRateOracleWrapper.deployed();

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
        await this.OneBtc.registerVault(pubX, pubY, {from:this.vaultId, value: collateral});
        const vault = await this.OneBtc.vaults(this.vaultId);
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(collateral, vault.collateral.toString());
    });
    it("issue test", async function() {
        const IssueAmount = 0.5 * 1e8;  // 0.5 OneBtc
        const Collateral = await this.ExchangeRateOracleWrapper.wrappedToCollateral(IssueAmount);
        const collateralForIssued = Collateral * 150 / 100;
        const griefingCollateral = collateralForIssued * 5 / 1000;

        const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {from: this.issueRequester, value:griefingCollateral});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequested')[0];
        const issueId = IssueEvent.args.issueId;
        const btcAddress = IssueEvent.args.btcAddress;
        const btcBase58 = bitcoin.address.toBase58Check(Buffer.from(btcAddress.slice(2), 'hex'), 0);
        const btcTx = issueTxMock(issueId, btcBase58, IssueAmount);
        const btcBlockNumberMock = 1000;
        const btcTxIndexMock = 2;
        const heightAndIndex = btcBlockNumberMock<<32|btcTxIndexMock;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        const outputIndexMock = 0;
        await this.OneBtc.executeIssue(this.issueRequester, issueId, proofMock, btcTx.toBuffer(), heightAndIndex, headerMock, outputIndexMock);
        const OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
        const OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
        assert.equal(OneBtcBalance.toString(), IssueEvent.args.amount.toString());
        assert.equal(OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());
    });
    it("redeem test", async function() {
        const RedeemAmount = 0.1 * 1e8;
        await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, { from: this.issueRequester });

        const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {from: this.redeemRequester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequested')[0];
        const redeemId = RedeemEvent.args.redeemId;
        
        const btcAmount = RedeemEvent.args.amount;
        const btcAddress = RedeemEvent.args.btcAddress;
        const btcBase58 = bitcoin.address.toBase58Check(Buffer.from(btcAddress.slice(2), 'hex'), 0);
        const btcTx = issueTxMock(redeemId, btcBase58, Number(btcAmount));
        const btcBlockNumberMock  = 1000;
        btcTxIndexMock = 2;
        btcTxHeightMock = btcBlockNumberMock << 32;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        const execRedeem = await this.OneBtc.executeRedeem(this.redeemRequester, redeemId, proofMock, btcTx.toBuffer(), btcTxIndexMock, btcTxHeightMock, headerMock);
        const redeemEvent = execRedeem.logs.filter(log=>log.event == 'RedeemCompleted')[0];
        assert.equal(redeemEvent.args.requester, this.redeemRequester);
    });
    it("cancel issue request test", async function() {
        const IssueAmount = 0.1 * 1e8;  // 0.1 OneBtc
        const Collateral = await this.ExchangeRateOracleWrapper.wrappedToCollateral(IssueAmount);
        const collateralForIssued = Collateral * 150 / 100;
        const griefingCollateral = collateralForIssued * 5 / 1000;

        const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {from: this.issueRequester, value:griefingCollateral});
        const IssueEvent = IssueReq.logs.filter(log=>log.event == 'IssueRequested')[0];
        const issueId = IssueEvent.args.issueId;
        const request = await this.OneBtc.issueRequests(this.issueRequester, issueId);
        await expectRevert(this.OneBtc.cancelIssue(this.issueRequester, issueId), 'Time not expired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancelIssue(this.issueRequester, issueId);
    });
    it("cancle redeem request test", async function() {
        const RedeemAmount = 0.1*1e8;  // 0.1 OneBtc
        await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, {from: this.issueRequester});
        const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {from: this.redeemRequester});
        const RedeemEvent = RedeemReq.logs.filter(log=>log.event == 'RedeemRequested')[0];
        const redeemId = RedeemEvent.args.redeemId;

        const request = await this.OneBtc.redeemRequests(this.redeemRequester, redeemId);
        
        const reimburse = true;
        await expectRevert(this.OneBtc.cancelRedeem(this.redeemRequester, redeemId, reimburse), 'Time not expired');
        await web3.miner.incTime(Number(request.period)+1);
        await this.OneBtc.cancelRedeem(this.redeemRequester, redeemId, reimburse);
    });
});