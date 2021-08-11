const VaultRegistryTestWrapper = artifacts.require("VaultRegistryTestWrapper");

const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const bitcoin = require("bitcoinjs-lib");
const { issueTxMock } = require("../mock/btcTxMock");
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

contract("VaultRegistry unit test", (accounts) => {
  before(async function () {
    this.VaultRegistry = await VaultRegistryTestWrapper.new();

    this.vaultId = accounts[1];
    this.issueRequester = accounts[2];
    this.redeemRequester = accounts[3];

    this.VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });

    const ecPair = bitcoin.ECPair.makeRandom({ compressed: false });
    const script = bitcoin.payments.p2pkh({ pubkey: ecPair.publicKey });
    this.redeemBtcAddress = "0x" + script.hash.toString("hex");
  });

  it("register new vault", async function () {
    const pubX = bn(this.VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(this.VaultEcPair.publicKey.slice(33, 65));

    this.initCollateral = web3.utils.toWei("10");

    const req = await this.VaultRegistry.registerVault(pubX, pubY, {
      from: this.vaultId,
      value: this.initCollateral,
    });

    const event = req.logs.filter((log) => log.event == "RegisterVault")[0];

    assert.equal(pubX.toString(), event.args.btcPublicKeyX.toString());
    assert.equal(pubY.toString(), event.args.btcPublicKeyY.toString());
    assert.equal(this.initCollateral, event.args.collateral.toString());
    assert.equal(this.vaultId, event.args.vaultId.toString());
  });

  it("after register: check vault method", async function () {
    const vault = await this.VaultRegistry.vaults(this.vaultId);

    const pubX = bn(this.VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(this.VaultEcPair.publicKey.slice(33, 65));
    const collateral = web3.utils.toWei("10");

    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(pubY.toString(), vault.btcPublicKeyY.toString());
    assert.equal(collateral, vault.collateral.toString());
  });

  it("update vault public key", async function () {
    this.VaultEcPair = bitcoin.ECPair.makeRandom({ compressed: false });

    const pubX = bn(this.VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(this.VaultEcPair.publicKey.slice(33, 65));

    const req = await this.VaultRegistry.updatePublicKey(pubX, pubY, {
      from: this.vaultId,
    });

    const event = req.logs.filter(
      (log) => log.event == "VaultPublicKeyUpdate"
    )[0];

    assert.equal(pubX.toString(), event.args.x.toString());
    assert.equal(pubY.toString(), event.args.y.toString());
    assert.equal(this.vaultId, event.args.vaultId.toString());
  });

  it("after public key update: check vault data", async function () {
    const vault = await this.VaultRegistry.vaults(this.vaultId);

    const pubX = bn(this.VaultEcPair.publicKey.slice(1, 33));
    const pubY = bn(this.VaultEcPair.publicKey.slice(33, 65));

    assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
    assert.equal(pubY.toString(), vault.btcPublicKeyY.toString());
  });

  it("Free Collateral is correct", async function () {
    const amount = await this.VaultRegistry.getFreeCollateral_public(
      this.vaultId
    );

    assert.equal(this.initCollateral, amount);
  });

  // it("set Oracle ExchangeRate", async function () {
  //   const req = await this.VaultRegistry.setExchangeRate(1);
  //
  //   console.log(req);
  // });
  //
  // it("issuableTokens is correct", async function () {
  //   const req = await this.VaultRegistry.issuableTokens(this.vaultId);
  //
  //   console.log(req);
  // });

  it("tryIncreaseToBeIssuedTokens", async function () {
    const amount = web3.utils.toWei("5");

    const req = await this.VaultRegistry.tryIncreaseToBeIssuedTokens_public(
      this.vaultId,
      amount
    );

    const event = req.logs.filter(
      (log) => log.event == "IncreaseToBeIssuedTokens"
    )[0];

    assert.equal(event.args.vaultId, this.vaultId);
    assert.equal(event.args.amount, amount);
  });

  it("Register Deposit Address", async function () {
    await this.VaultRegistry.registerDepositAddress_public(this.vaultId, 1);

    this.depositAddress = await this.VaultRegistry.getLastDepositAddress();

    assert.equal(!!this.depositAddress, true);
  });

  it("Issue tokens 5 Wei", async function () {
    const amount = web3.utils.toWei("5");

    const req = await this.VaultRegistry.issueTokens_public(
      this.vaultId,
      amount
    );

    const event = req.logs.filter((log) => log.event == "IssueTokens")[0];

    assert.equal(this.vaultId, event.args.vaultId);
    assert.equal(amount, event.args.amount);
  });

  it("after issue: Check issued amount equal 5 Wei", async function () {
    const amount = await this.VaultRegistry.issued(this.vaultId);
    assert.equal(amount, web3.utils.toWei("5"));
  });

  it("tryIncreaseToBeRedeemedTokens", async function () {
    const amount = web3.utils.toWei("5");

    const req = await this.VaultRegistry.tryIncreaseToBeRedeemedTokens_public(
      this.vaultId,
      amount
    );

    const event = req.logs.filter(
      (log) => log.event == "IncreaseToBeRedeemedTokens"
    )[0];

    const vault = await this.VaultRegistry.vaults(this.vaultId);

    assert.equal(vault.toBeRedeemed, amount);
    assert.equal(event.args.vaultId, this.vaultId);
    assert.equal(event.args.amount, amount);
  });

  it("Redeem tokens 5 Wei", async function () {
    const amount = web3.utils.toWei("5");

    const req = await this.VaultRegistry.redeemTokens_public(
      this.vaultId,
      amount
    );

    const event = req.logs.filter((log) => log.event == "RedeemTokens")[0];

    assert.equal(this.vaultId, event.args.vaultId);
    assert.equal(amount, event.args.amount);

    const vault = await this.VaultRegistry.vaults(this.vaultId);

    assert.equal(vault.toBeRedeemed, 0);
  });
});
