const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");

const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const { issueTxMock } = require("./mock/btcTxMock");

const bitcoin = require("bitcoinjs-lib");
const bn = (b) => BigInt(`0x${b.toString("hex")}`);

contract("Issue unit test", (accounts) => {
  before(async function () {
    const IRelay = await RelayMock.new();
    this.OneBtc = await OneBtc.new(IRelay.address);

    this.vaultId = accounts[1];
    this.issueRequester = accounts[2];

    this.OneBtcBalance = 0;
    this.OneBtcBalanceVault = 0;
  });

  it("Error on requestIssue with the exceeding vault limit", async function () {
    const IssueAmount = Math.floor(10 * 1e8 * 100 / 150) + 1; // threshold = 150

    await expectRevert(this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    }), 'ExceedingVaultLimit');
  });

  it("Register Vault with 10 Wei Collateral", async function () {
    const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

    const collateral = 10 * 1e8;
    await this.OneBtc.registerVault(pubX, pubY, {
      from: this.vaultId,
      value: collateral,
    });
    const vault = await this.OneBtc.vaults(this.vaultId);
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(collateral, vault.collateral.toString());
  });

  it("Error on requestIssue with the insufficient collateral", async function () {
    const IssueAmount = 1 * 1e8;

    await expectRevert(this.OneBtc.requestIssue(IssueAmount+1, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    }), 'InsufficientCollateral');
  });

  it("Issue 1 BTC", async function () {
    const IssueAmount = 1 * 1e8;
    const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    });
    const IssueEvent = IssueReq.logs.filter(
      (log) => log.event == "IssueRequest"
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
    const ExecuteReq = await this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock
    );

    this.OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
    this.OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(this.OneBtcBalance.toString(), IssueEvent.args.amount.toString());
    assert.equal(this.OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());

    const ExecuteEvent = ExecuteReq.logs.filter(
      (log) => log.event == "IssueComplete"
    )[0];
    assert.equal(ExecuteEvent.args.issuedId.toString(), issueId.toString());
  });

  it("Error on requester is not a executor of issue call", async function () {
    const IssueAmount = 1 * 1e8;
    const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    });
    const IssueEvent = IssueReq.logs.filter(
      (log) => log.event == "IssueRequest"
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

    await expectRevert(this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock
    ), 'InvalidExecutor');
  });
  
  it("Slash in case the transferred BTC amount is smaller than the requested OneBTC amount", async function () {
    const IssueAmount = 1 * 1e8;
    const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    });
    const IssueEvent = IssueReq.logs.filter(
      (log) => log.event == "IssueRequest"
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
    const ExecuteReq = await this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock,
      {
        from: this.issueRequester
      }
    );
    const ExecuteEvent = ExecuteReq.logs.filter(
      (log) => log.event == "SlashCollateral"
    )[0];
    assert.equal(ExecuteEvent.args.amount, IssueAmount - (IssueAmount / 4));

    const beforeOneBtcBalance = this.OneBtcBalance;
    const beforeOneBtcBalanceVault = this.OneBtcBalanceVault;
    this.OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
    this.OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(this.OneBtcBalance.toString(), (Number(beforeOneBtcBalance)+IssueEvent.args.amount/4).toString());
    assert.equal(this.OneBtcBalanceVault.toString(), (Number(beforeOneBtcBalanceVault) + IssueEvent.args.fee/4).toString());
  });

  it("Error on cancelIssue with the invalid cancel period", async function () {
    const IssueAmount = 1 * 1e8;
    const IssueReq = await this.OneBtc.requestIssue(IssueAmount, this.vaultId, {
      from: this.issueRequester,
      value: IssueAmount,
    });
    const IssueEvent = IssueReq.logs.filter(
      (log) => log.event == "IssueRequest"
    )[0];
    const issueId = IssueEvent.args.issueId;
    const btcAddress = IssueEvent.args.btcAddress;
    const btcBase58 = bitcoin.address.toBase58Check(
      Buffer.from(btcAddress.slice(2), "hex"),
      0
    );

    await expectRevert(this.OneBtc.cancelIssue(this.issueRequester, issueId), 'TimeNotExpired');
  });
});
