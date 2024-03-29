const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
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
    this.RelayMock = await RelayMock.new();
    this.ExchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);
    this.OneBtc = await deployProxy(OneBtc, [this.RelayMock.address, this.ExchangeRateOracleWrapper.address]);

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

  it("Register Vault with 10 ONE Collateral", async function () {
    const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

    const collateral = 10 * 1e18;  // 10 ONE
    await this.OneBtc.registerVault(pubX, pubY, {
      from: this.vaultId,
      value: collateral,
    });
    const vault = await this.OneBtc.vaults(this.vaultId);
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(collateral, vault.collateral.toString());
  });

  it("Issue 0.5 OneBtc", async function () {
    const IssueAmount = 0.5 * 1e8;  // 0.5 OneBtc
    const Collateral = await this.ExchangeRateOracleWrapper.wrappedToCollateral(IssueAmount);
    const collateralForIssued = Collateral * 150 / 100;
    const griefingCollateral = collateralForIssued * 5 / 1000;

    const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: griefingCollateral,
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
    const outputIndexMock = 0;
    const ExecuteReq = await this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock,
      outputIndexMock
    );
  });

  it("Redeem 0.1 OneBtc", async function () {
    // Transfer 0.1 OneBTC
    const RedeemAmount = 0.1 * 1e8;
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
      btcTxIndexMock,
      btcTxHeightMock,
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
      btcTxIndexMock,
      btcTxHeightMock,
      headerMock
    ), 'Request is already completed');

    // should not cancel the request which has been already completed
    const reimburse = true;
    await expectRevert(this.OneBtc.cancelRedeem(
      this.redeemRequester,
      redeemId,
      reimburse
    ), 'Request is already completed');
  });

  it("Error on cancelRedeem with the invalid cancel period", async function () {
    // Transfer 0.1 OneBTC
    const RedeemAmount = 0.1 * 1e8;
    await this.OneBtc.transfer(this.redeemRequester, RedeemAmount, { from: this.issueRequester });

    // Redeem 0.1 OneBTC
    const RedeemReq = await this.OneBtc.requestRedeem(RedeemAmount, this.redeemBtcAddress, this.vaultId, {
      from: this.redeemRequester
    });
    const RedeemEvent = RedeemReq.logs.filter(
      (log) => log.event == "RedeemRequested"
    )[0];
    const redeemId = RedeemEvent.args.redeemId;

    const reimburse = true;
    await expectRevert(this.OneBtc.cancelRedeem(
      this.redeemRequester,
      redeemId,
      reimburse
    ), 'Time not expired');
  });

  it("Cancel Redeem", async function () {
    // Transfer 0.1 OneBTC
    const RedeemAmount = 0.1 * 1e8;
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

    const reimburse = true;
    const CancelReq = await this.OneBtc.cancelRedeem(this.redeemRequester, redeemId, reimburse);
    const CancelEvent = CancelReq.logs.filter(
      (log) => log.event == "RedeemCanceled"
    )[0];
    assert.equal(CancelEvent.args.redeemId.toString(), redeemId.toString());
  });
});
