const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const VaultRegistryWrapper = artifacts.require("VaultRegistryWrapper");

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

contract("VaultRegistry unit test", (accounts) => {
  before(async function () {
    this.ExchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);
    this.VaultRegistry = await deployProxy(VaultRegistryWrapper, [this.ExchangeRateOracleWrapper.address]);

    // set OneBtc address with accounts[0]
    await this.VaultRegistry.setOneBtcAddress(accounts[0]);

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
    const amount = await this.VaultRegistry.testGetFreeCollateral(
      this.vaultId
    );

    assert.equal(this.initCollateral, amount);
  });

  it("Register Deposit Address", async function () {
    await this.VaultRegistry.testRegisterDepositAddress(this.vaultId, 1);

    this.depositAddress = await this.VaultRegistry.getLastDepositAddress();

    assert.equal(!!this.depositAddress, true);
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

    const req = await this.VaultRegistry.testTryIncreaseToBeIssuedTokens(
      this.vaultId,
      amount
    );

    const event = req.logs.filter(
      (log) => log.event == "IncreaseToBeIssuedTokens"
    )[0];

    assert.equal(event.args.vaultId, this.vaultId);
    assert.equal(event.args.amount, amount);
  });

  it("tryDecreaseToBeIssuedTokens", async function () {
    const amount = web3.utils.toWei("2");

    const req = await this.VaultRegistry.testDecreaseToBeIssuedTokens(
      this.vaultId,
      amount
    );

    const event = req.logs.filter(
      (log) => log.event == "DecreaseToBeIssuedTokens"
    )[0];

    assert.equal(event.args.vaultId, this.vaultId);
    assert.equal(event.args.amount, amount);
  });

  it("Issue tokens 2 Wei", async function () {
    const amount = web3.utils.toWei("2");

    const req = await this.VaultRegistry.testIssueTokens(
      this.vaultId,
      amount
    );

    const event = req.logs.filter((log) => log.event == "IssueTokens")[0];

    assert.equal(this.vaultId, event.args.vaultId);
    assert.equal(amount, event.args.amount);
  });

  it("after issue: Check issued amount equal 2 Wei", async function () {
    const vault = await this.VaultRegistry.vaults(this.vaultId);
    const amount = await vault.issued;
    assert.equal(amount, web3.utils.toWei("2"));
  });

  it("tryIncreaseToBeRedeemedTokens", async function () {
    const amount = web3.utils.toWei("1");

    const req = await this.VaultRegistry.testTryIncreaseToBeRedeemedTokens(
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

  it("Redeem tokens 1 Wei", async function () {
    const amount = web3.utils.toWei("1");

    const req = await this.VaultRegistry.testRedeemTokens(
      this.vaultId,
      amount
    );

    const event = req.logs.filter((log) => log.event == "RedeemTokens")[0];

    assert.equal(this.vaultId, event.args.vaultId);
    assert.equal(amount, event.args.amount);

    const vault = await this.VaultRegistry.vaults(this.vaultId);

    assert.equal(vault.toBeRedeemed, 0);
  });

  it("after redeem: Check redeemable amount equal 1 Wei", async function () {
    const amount = web3.utils.toWei("1");

    const req = await this.VaultRegistry.testRedeemableTokens(
      this.vaultId
    );

    const event = req.logs.filter((log) => log.event == "RedeemableTokens")[0];

    assert.equal(this.vaultId, event.args.vaultId);
    assert.equal(amount, event.args.amount);
  });

  it("RequestableToBeReplacedTokens", async function () {
    const vault = await this.VaultRegistry.vaults(this.vaultId);
    const issuedAmount = await vault.issued;
    const toBeRedeemedAmount = await vault.toBeRedeemed;
    const amount = issuedAmount.sub(toBeRedeemedAmount);

    const req = await this.VaultRegistry.testRequestableToBeReplacedTokens(
      this.vaultId
    );

    const event = req.logs.filter(
      (log) => log.event == "RequestableToBeReplacedTokens"
    )[0];

    assert.equal(event.args.vaultId, this.vaultId);
    assert.equal(event.args.amount.toString(), amount.toString());
  });
});
