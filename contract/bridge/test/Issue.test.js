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

contract("Issue unit test", (accounts) => {
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

    this.OneBtcBalance = 0;
    this.OneBtcBalanceVault = 0;
  });

  it("Register Vault with 100e18 Wei Collateral", async function () {
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
    assert.equal(collateral.toString(), vault.collateral.toString());
  });

  it("Error on requestIssue with the insufficient collateral", async function () {
    const IssueAmount = new BN('100000000'); // 1e8, 1 OneBtc

    await expectRevert(this.OneBtc.requestIssue(IssueAmount+1, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    }), 'Insufficient collateral');
  });

  it("Error on requestIssue with the exceeding vault limit", async function () {
    const collateral = new BN('10000000000000000000'); // 10e18, 10 ONE
    const IssueAmount = Math.floor(collateral * 100 / 150) + 1; // threshold = 150

    await expectRevert(this.OneBtc.requestIssue(IssueAmount.toString(), this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount.toString(),
    }), 'Amount requested exceeds vault limit');
  });

  it("Issue 0.1 BTC", async function () {
    const IssueAmount = new BN('10000000'); // 0.1e8, 0.1 OneBtc
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount.toNumber());
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
      ouputIndexMock
    ), 'Request is already completed');

    // should not cancel the request which has been already completed
    await expectRevert(this.OneBtc.cancelIssue(
      this.issueRequester,
      issueId
    ), 'Request is already completed');
  });

  it("Error on requester is not a executor of issue call", async function () {
    const IssueAmount = new BN('10000000'); // 0.1e8, 0.1 OneBtc
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount / 4);
    const btcBlockNumberMock = 1000;
    const btcTxIndexMock = 2;
    const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
    const headerMock = Buffer.alloc(0);
    const proofMock = Buffer.alloc(0);
    const ouputIndexMock = 0;
    await expectRevert(this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock,
      ouputIndexMock
    ), 'Invalid executor');
  });
  
  it("Slash in case the transferred BTC amount is smaller than the requested OneBTC amount", async function () {
    const IssueAmount = new BN('10000000'); // 0.1e8, 0.1 OneBtc
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount / 4);
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
      ouputIndexMock,
      {
        from: this.issueRequester
      }
    );

    const beforeOneBtcBalance = this.OneBtcBalance;
    const beforeOneBtcBalanceVault = this.OneBtcBalanceVault;
    this.OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
    this.OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(this.OneBtcBalance.toString(), (Number(beforeOneBtcBalance)+IssueEvent.args.amount/4).toString());
    assert.equal(this.OneBtcBalanceVault.toString(), (Number(beforeOneBtcBalanceVault) + IssueEvent.args.fee/4).toString());
  });

  it("Error on cancelIssue with the invalid cancel period", async function () {
    const IssueAmount = new BN('10000000'); // 0.1e8, 0.1 OneBtc
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

    await expectRevert(this.OneBtc.cancelIssue(this.issueRequester, issueId), 'Time not expired');
  });

  it("Cancel issue", async function () {
    const IssueAmount = new BN('10000000'); // 0.1e8, 0.1 OneBtc
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
