const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const VaultRegistry = artifacts.require("VaultRegistry");
const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const { issueTxMock } = require("./mock/btcTxMock");

const bitcoin = require("bitcoinjs-lib");
const bn = (b) => BigInt(`0x${b.toString("hex")}`);

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

contract("Redeem unit test", (accounts) => {
  before(async function () {
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

    this.vaultId = accounts[1];
    this.issueRequester = accounts[2];
    this.redeemRequester = accounts[3];

    this.OneBtcBalance = 0;
    this.OneBtcBalanceVault = 0;

    const ecPair = bitcoin.ECPair.makeRandom({compressed:false});
    const script = bitcoin.payments.p2pkh({pubkey:ecPair.publicKey})
    this.redeemBtcAddress = '0x'+script.hash.toString('hex');
  });

  it("Register Vault with 10e18 Wei Collateral", async function () {
    const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

    const collateral = new BN('10000000000000000000'); // 10e18, 10 ONE
    await this.VaultRegistry.registerVault(pubX, pubY, {
      from: this.vaultId,
      value: collateral,
    });
    const vault = await this.VaultRegistry.vaults(this.vaultId);
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(collateral, vault.collateral.toString());
  });

  it("Issue 0.5 BTC", async function () {
    const IssueAmount = new BN('50000000'); // 0.5e8, 0.5 OneBtc
    const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    });
    const IssueEvent = IssueReq.logs.filter(
      (log) => log.event == "IssueRequested"
    )[0];
    const issueId = IssueEvent.args.issueId;
    const btcAddress = IssueEvent.args.btcAddress;
    const btcBase58 = bitcoin.address.toBase58Check(
      Buffer.from(btcAddress.slice(2), "hex"),
      0
    );
    const btcTx = issueTxMock(issueId, btcBase58, Number(IssueAmount));
    const btcBlockNumberMock = 1000;
    const btcTxIndexMock = 2;
    const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
    const headerMock = Buffer.alloc(0);
    const proofMock = Buffer.alloc(0);
    const ouputIndexMock = 0;
    const ExecuteReq = await this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock,
      ouputIndexMock
    );
    const ExecuteReqEvent = ExecuteReq.logs.filter(
      (log) => log.event == "IssueCompleted"
    )[0];

    const fee = IssueAmount / 1000 * 2; // 0.2% fee
    const requesterAmount = await this.OneBtc.balanceOf(this.issueRequester);
    assert.equal(this.issueRequester, ExecuteReqEvent.args.requester);
    assert.equal(requesterAmount.toString(), ExecuteReqEvent.args.amount.toString());
    assert.equal(fee.toString(), ExecuteReqEvent.args.fee.toString());
  });

  it("Redeem 0.1 BTC", async function () {
    // Transfer 0.1 OneBTC
    const RedeemAmount = new BN('1000000'); // 0.1e8, 0.1 OneBtc
    await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, { from: this.issueRequester });

    // Redeem 0.1 OneBTC
    const beforeOneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);

    const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {
      from: this.redeemRequester
    });
    const RedeemEvent = RedeemReq.logs.filter(
      (log) => log.event == "RedeemRequested"
    )[0];
    const redeemId = RedeemEvent.args.redeemId;
    const amountBtc = RedeemEvent.args.amount;
    const btcAddress = RedeemEvent.args.btcAddress;
    const btcBase58 = bitcoin.address.toBase58Check(
      Buffer.from(btcAddress.slice(2), "hex"),
      0
    );
    btcTx = issueTxMock(redeemId, btcBase58, Number(amountBtc));
    btcBlockNumberMock = 1000;
    btcTxIndexMock = 2;
    btcTxHeightMock = btcBlockNumberMock << 32;
    headerMock = Buffer.alloc(0);
    proofMock = Buffer.alloc(0);
    const ExecuteReq = await this.OneBtc.executeRedeem(
      this.redeemRequester,
      redeemId,
      proofMock,
      btcTx.toBuffer(),
      btcTxHeightMock,
      btcTxIndexMock,
      headerMock
    );

    const ExecuteEvent = ExecuteReq.logs.filter(
      (log) => log.event == "RedeemCompleted"
    )[0];
    this.OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(this.OneBtcBalanceVault.toString(), (Number(beforeOneBtcBalanceVault) + Number(ExecuteEvent.args.fee)).toString());
    assert.equal(this.redeemRequester, ExecuteEvent.args.requester);

    // should not execute the request which has been already used
    await expectRevert(this.OneBtc.executeRedeem(
      this.redeemRequester,
      redeemId,
      proofMock,
      btcTx.toBuffer(),
      btcTxHeightMock,
      btcTxIndexMock,
      headerMock
    ), 'Request is already completed');

    // should not cancel the request which has been already completed
    await expectRevert(this.OneBtc.cancelRedeem(
      this.redeemRequester,
      redeemId
    ), 'Request is already completed');
  });

  it("Error on cancelRedeem with the invalid cancel period", async function () {
    // Transfer 0.1 OneBTC
    const RedeemAmount = new BN('1000000'); // 0.1e8, 0.1 OneBtc
    await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, { from: this.issueRequester });

    // Redeem 0.1 OneBTC
    const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {
      from: this.redeemRequester
    });
    const RedeemEvent = RedeemReq.logs.filter(
      (log) => log.event == "RedeemRequested"
    )[0];
    const redeemId = RedeemEvent.args.redeemId;

    await expectRevert(this.OneBtc.cancelRedeem(
      this.redeemRequester,
      redeemId,
    ), 'Time not expired');
  });

  it("Cancel Redeem", async function () {
    // Transfer 1 OneBTC
    const RedeemAmount = new BN('10000000'); // 0.1e8, 0.1 OneBtc
    await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, { from: this.issueRequester });

    // Redeem 1 OneBTC
    const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {
      from: this.redeemRequester
    });
    const RedeemEvent = RedeemReq.logs.filter(
      (log) => log.event == "RedeemRequested"
    )[0];
    const redeemId = RedeemEvent.args.redeemId;

    // increase time
    await web3.miner.incTime(Number(3600 *24 * 2 + 1)); // valid expire time = after 2 days
    await web3.miner.mine();

    const CancelReq = await this.OneBtc.cancelRedeem(this.redeemRequester, redeemId);
    const CancelEvent = CancelReq.logs.filter(
      (log) => log.event == "RedeemCanceled"
    )[0];
    assert.equal(CancelEvent.args.redeemId.toString(), redeemId.toString());
  });
});
