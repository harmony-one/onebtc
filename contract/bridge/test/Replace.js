const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const { issueTxMock } = require("./mock/btcTxMock");

const bitcoin = require("bitcoinjs-lib");
const bn = (b) => BigInt(`0x${b.toString("hex")}`);

contract("Replace unit test", (accounts) => {
  before(async function () {
    this.name = "name";
    const IRelay = await RelayMock.new();
    this.OneBtc = await OneBtc.new(IRelay.address);

    this.vaultId = accounts[1];
    this.issueRequester = accounts[2];
    this.newVaultId = accounts[3];
  });

  it("Register OLD Vault with 10 Wei Collateral", async function () {
    const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

    const collateral = web3.utils.toWei("10");
    await this.OneBtc.registerVault(pubX, pubY, {
      from: this.vaultId,
      value: collateral,
    });
    const vault = await this.OneBtc.vaults(this.vaultId);
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(collateral, vault.collateral.toString());
  });

  it("Issue 0.01 BTC", async function () {
    const IssueAmount = 0.01 * 1e8;
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount);
    const btcBlockNumberMock = 1000;
    const btcTxIndexMock = 2;
    const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
    const headerMock = Buffer.alloc(0);
    const proofMock = Buffer.alloc(0);
    await this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock
    );
    const OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
    const OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(OneBtcBalance.toString(), IssueEvent.args.amount.toString());
    assert.equal(OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());
  });

  it("Request Replace", async function () {
    const btcAmount = 0.001 * 1e8;
    const collateral = 0.01 * 1e8;

    const req = await this.OneBtc.requestReplace(
      this.vaultId,
      btcAmount,
      collateral,
      { from: this.vaultId, value: collateral }
    );

    const IssueEvent = req.logs.filter(
      (log) => log.event == "RequestReplace"
    )[0];

    assert.equal(this.vaultId.toString(), IssueEvent.args.oldVault.toString());
    assert.equal(btcAmount.toString(), IssueEvent.args.btcAmount.toString());
    assert.equal(
      collateral.toString(),
      IssueEvent.args.griefingCollateral.toString()
    );
  });

  it("Register NEW Vault with 10 Wei Collateral", async function () {
    const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

    const collateral = web3.utils.toWei("10");
    await this.OneBtc.registerVault(pubX, pubY, {
      from: this.newVaultId,
      value: collateral,
    });
    const vault = await this.OneBtc.vaults(this.newVaultId);
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(collateral, vault.collateral.toString());
  });

  it("Accept Replace", async function () {
    const btcAmount = 0.001 * 1e8;
    const collateral = 0.01 * 1e8;

    const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

    const req = await this.OneBtc.acceptReplace(
      this.vaultId,
      this.newVaultId,
      btcAmount,
      collateral,
      pubX,
      pubY,
      { from: this.newVaultId, value: collateral }
    );

    const reqEvent = req.logs.filter((log) => log.event == "AcceptReplace")[0];

    // assert.equal(this.replaceId.toString(), reqEvent.args.replaceId.toString());
    assert.equal(this.vaultId.toString(), reqEvent.args.oldVault.toString());
    assert.equal(this.newVaultId.toString(), reqEvent.args.newVault.toString());
    assert.equal(btcAmount.toString(), reqEvent.args.btcAmount.toString());
    assert.equal(collateral.toString(), reqEvent.args.collateral.toString());

    this.replaceBtcAddress = reqEvent.args.btcAddress.toString();
    this.replaceId = reqEvent.args.replaceId.toString();
  });

  // it("Execute Replace", async function() {
  //
  // });
});
