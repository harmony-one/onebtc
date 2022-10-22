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

contract("Issue unit test", (accounts) => {
  before(async function () {
    this.OneBtc = await OneBtc.deployed()
    this.ExchangeRateOracleWrapper = await ExchangeRateOracleWrapper.deployed();

    // set BTC/ONE exchange rate
    await this.ExchangeRateOracleWrapper.setExchangeRate(10); // 1 OneBtc = 10 ONE

    // increase time to be enable exchange rate
    await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
    await web3.miner.mine();

    this.vaultId = accounts[1];
    this.issueRequester = accounts[2];

    this.OneBtcBalance = 0;
    this.OneBtcBalanceVault = 0;
  });

  it("Error on requestIssue with the insufficient griefing collateral", async function () {
    const IssueAmount = 1 * 1e8;  // 1 OneBtc
    const Collateral = await this.ExchangeRateOracleWrapper.wrappedToCollateral(IssueAmount);
    const collateralForIssued = Collateral * 150 / 100;
    const griefingCollateral = collateralForIssued * 5 / 1000;

    await expectRevert(this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: griefingCollateral * 0.99,
    }), 'Insufficient griefing collateral');
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

  it("Error on requestIssue with the exceeding vault limit", async function () {
    const IssueAmount = 1 * 1e8;  // 1 OneBtc
    const Collateral = await this.ExchangeRateOracleWrapper.wrappedToCollateral(IssueAmount);
    const collateralForIssued = Collateral * 150 / 100;
    const griefingCollateral = collateralForIssued * 5 / 1000;

    await expectRevert(this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: griefingCollateral,
    }), 'Amount requested exceeds vault limit');
  });

  it("Issue 0.1 OneBtc", async function () {
    const IssueAmount = 0.1 * 1e8;  // 0.1 OneBtc
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount);
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

    this.OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
    this.OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(this.OneBtcBalance.toString(), IssueEvent.args.amount.toString());
    assert.equal(this.OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());

    const ExecuteEvent = ExecuteReq.logs.filter(
      (log) => log.event == "IssueCompleted"
    )[0];
    assert.equal(ExecuteEvent.args.issuedId.toString(), issueId.toString());

    // should not execute the request which has been already used
    await expectRevert(this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock,
      outputIndexMock
    ), 'Request is already completed');

    // should not cancel the request which has been already completed
    await expectRevert(this.OneBtc.cancelIssue(
      this.issueRequester,
      issueId
    ), 'Request is already completed');
  });

  it("Error on requester is not a executor of issue call", async function () {
    const IssueAmount = 0.1 * 1e8;  // 0.1 OneBtc
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount / 4);
    const btcBlockNumberMock = 1000;
    const btcTxIndexMock = 2;
    const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
    const headerMock = Buffer.alloc(0);
    const proofMock = Buffer.alloc(0);
    const outputIndexMock = 0;

    await expectRevert(this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock,
      outputIndexMock
    ), 'Invalid executor');
  });
  
  it("Slash in case the transferred BTC amount is smaller than the requested OneBTC amount", async function () {
    const IssueAmount = 0.1 * 1e8;  // 0.1 OneBtc
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount / 4);
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
      outputIndexMock,
      {
        from: this.issueRequester
      }
    );
    const ExecuteEvent = ExecuteReq.logs.filter(
      (log) => log.event == "SlashCollateral"
    )[0];
    assert.equal(ExecuteEvent.args.amount.toString(), griefingCollateral - (griefingCollateral / 4));

    const beforeOneBtcBalance = this.OneBtcBalance;
    const beforeOneBtcBalanceVault = this.OneBtcBalanceVault;
    this.OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
    this.OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(this.OneBtcBalance.toString(), (Number(beforeOneBtcBalance)+IssueEvent.args.amount/4).toString());
    assert.equal(this.OneBtcBalanceVault.toString(), (Number(beforeOneBtcBalanceVault) + IssueEvent.args.fee/4).toString());
  });

  it("Error on cancelIssue with the invalid cancel period", async function () {
    const IssueAmount = 0.1 * 1e8;  // 0.1 OneBtc
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

    await expectRevert(this.OneBtc.cancelIssue(this.issueRequester, issueId), 'Time not expired');
  });

  it("Cancel issue", async function () {
    const IssueAmount = 0.1 * 1e8;  // 0.1 OneBtc
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

    // increase time
    await web3.miner.incTime(Number(3600 *24 * 2 + 1)); // valid expire time = after 2 days
    await web3.miner.mine();

    const CancelReq = await this.OneBtc.cancelIssue(this.issueRequester, issueId);
    const CancelEvent = CancelReq.logs.filter(
      (log) => log.event == "IssueCanceled"
    )[0];
    assert.equal(CancelEvent.args.issuedId.toString(), issueId.toString());
  });
});
