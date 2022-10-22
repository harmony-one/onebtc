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

contract("Replace unit test", (accounts) => {
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
    const btcTx = issueTxMock(issueId, btcBase58, IssueAmount);
    const btcBlockNumberMock = 1000;
    const btcTxIndexMock = 2;
    const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
    const headerMock = Buffer.alloc(0);
    const proofMock = Buffer.alloc(0);
    const outputIndexMock = 0;
    await this.OneBtc.executeIssue(
      this.issueRequester,
      issueId,
      proofMock,
      btcTx.toBuffer(),
      heightAndIndex,
      headerMock,
      outputIndexMock
    );
    const OneBtcBalance = await this.OneBtc.balanceOf(this.issueRequester);
    const OneBtcBalanceVault = await this.OneBtc.balanceOf(this.vaultId);
    assert.equal(OneBtcBalance.toString(), IssueEvent.args.amount.toString());
    assert.equal(OneBtcBalanceVault.toString(), IssueEvent.args.fee.toString());
  });

  // it("Request Replace", async function () {
  //   const btcAmount = 0.001 * 1e8;
  //   const collateral = 0.01 * 1e8;

  //   const req = await this.OneBtc.requestReplace(
  //     this.vaultId,
  //     btcAmount,
  //     collateral,
  //     { from: this.vaultId, value: collateral }
  //   );

  //   const IssueEvent = req.logs.filter(
  //     (log) => log.event == "RequestReplace"
  //   )[0];

  //   assert.equal(this.vaultId.toString(), IssueEvent.args.oldVault.toString());
  //   assert.equal(btcAmount.toString(), IssueEvent.args.btcAmount.toString());
  //   assert.equal(
  //     collateral.toString(),
  //     IssueEvent.args.griefingCollateral.toString()
  //   );
  // });

  // it("Register NEW Vault with 10 Wei Collateral", async function () {
  //   const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
  //   const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
  //   const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

  //   const collateral = web3.utils.toWei("10");
  //   await this.OneBtc.registerVault(pubX, pubY, {
  //     from: this.newVaultId,
  //     value: collateral,
  //   });
  //   const vault = await this.OneBtc.vaults(this.newVaultId);
  //   assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
  //   assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
  //   assert.equal(collateral, vault.collateral.toString());
  // });

  // it("Accept Replace", async function () {
  //   const btcAmount = 0.001 * 1e8;
  //   const collateral = 0.01 * 1e8;

  //   const VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });
  //   const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
  //   const pubY = bn(VaultEcPair.publicKey.slice(33, 65));

  //   const req = await this.OneBtc.acceptReplace(
  //     this.vaultId,
  //     this.newVaultId,
  //     btcAmount,
  //     collateral,
  //     pubX,
  //     pubY,
  //     { from: this.newVaultId, value: collateral }
  //   );

  //   const reqEvent = req.logs.filter((log) => log.event == "AcceptReplace")[0];

  //   // assert.equal(this.replaceId.toString(), reqEvent.args.replaceId.toString());
  //   assert.equal(this.vaultId.toString(), reqEvent.args.oldVault.toString());
  //   assert.equal(this.newVaultId.toString(), reqEvent.args.newVault.toString());
  //   assert.equal(btcAmount.toString(), reqEvent.args.btcAmount.toString());
  //   assert.equal(collateral.toString(), reqEvent.args.collateral.toString());

  //   this.replaceBtcAddress = reqEvent.args.btcAddress.toString();
  //   this.replaceId = reqEvent.args.replaceId;
  // });

  // it("Execute Replace", async function () {
  //   const btcAmount = 0.001 * 1e8;
  //   const replaceId = this.replaceId;
  //   const btcAddress = this.replaceBtcAddress;

  //   const btcBase58 = bitcoin.address.toBase58Check(
  //     Buffer.from(btcAddress.slice(2), "hex"),
  //     0
  //   );
  //   const btcTx = issueTxMock(replaceId, btcBase58, btcAmount);
  //   const btcBlockNumberMock = 1000;
  //   const btcTxIndexMock = 2;
  //   const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
  //   const headerMock = Buffer.alloc(0);
  //   const proofMock = Buffer.alloc(0);

  //   const req = await this.OneBtc.executeReplace(
  //     replaceId,
  //     proofMock,
  //     btcTx.toBuffer(),
  //     heightAndIndex,
  //     headerMock
  //   );

  //   const reqEvent = req.logs.filter((log) => log.event == "ExecuteReplace")[0];

  //   assert.equal(this.vaultId.toString(), reqEvent.args.oldVault.toString());
  //   assert.equal(this.newVaultId.toString(), reqEvent.args.newVault.toString());
  //   assert.equal(this.replaceId.toString(), reqEvent.args.replaceId.toString());
  // });
});
