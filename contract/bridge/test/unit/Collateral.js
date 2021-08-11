const BN = require("bn.js");
const CollateralTestWrapper = artifacts.require("CollateralTestWrapper");

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

contract("Collateral unit test", (accounts) => {
  before(async function () {
    this.CollateralTestWrapper = await CollateralTestWrapper.new();

    this.vaultId = accounts[1];
    this.vaultId_new = accounts[3];
    this.vaultId_new_initBalance = await web3.eth.getBalance(this.vaultId_new);
    this.lockAmount = 1e9; // 1 Gwei
  });

  it("init totalCollateral is zero", async function () {
    const totalCollateral = await this.CollateralTestWrapper.TotalCollateral();
    assert.equal(Number(totalCollateral), 0);
  });

  it("Error on lockCollateral with 0 amount", async function () {
    let errorMessage = "";

    try {
      await this.CollateralTestWrapper.lockCollateral_public(
        this.vaultId,
        this.lockAmount,
        {
          from: accounts[0],
          value: 0,
        }
      );
    } catch (e) {
      errorMessage = e.message.split("Reason given: ")[1];
    }

    assert.equal(errorMessage, "InvalidCollateral.");
  });

  it("LockCollateral with 1 Gwei amount", async function () {
    const lockCollateralReq =
      await this.CollateralTestWrapper.lockCollateral_public(
        this.vaultId,
        this.lockAmount,
        {
          from: accounts[0],
          value: this.lockAmount,
        }
      );

    const lockEvent = lockCollateralReq.logs.filter(
      (log) => log.event == "LockCollateral"
    )[0];

    assert.equal(lockEvent.args.sender, this.vaultId);
    assert.equal(lockEvent.args.amount, this.lockAmount);
  });

  it("after lock: totalCollateral equal 1 Gwei", async function () {
    const totalCollateral = await this.CollateralTestWrapper.TotalCollateral();
    assert.equal(Number(totalCollateral), this.lockAmount);
  });

  it("after lock: freeCollateral equal 1 Gwei", async function () {
    const freeCollateral =
      await this.CollateralTestWrapper.getFreeCollateral_public(this.vaultId);
    assert.equal(Number(freeCollateral), this.lockAmount);
  });

  it("ReleaseCollateral 0.5 Gwei", async function () {
    const req = await this.CollateralTestWrapper.releaseCollateral_public(
      this.vaultId,
      0.5 * 1e9
    );

    const event = req.logs.filter((log) => log.event == "ReleaseCollateral")[0];

    assert.equal(event.args.sender, this.vaultId);
    assert.equal(event.args.amount, 0.5 * 1e9);
  });

  it("after release: totalCollateral equal 0.5 Gwei", async function () {
    const totalCollateral = await this.CollateralTestWrapper.TotalCollateral();
    assert.equal(Number(totalCollateral), 0.5 * 1e9);
  });

  it("after release: freeCollateral equal 0.5 Gwei", async function () {
    const freeCollateral =
      await this.CollateralTestWrapper.getFreeCollateral_public(this.vaultId);
    assert.equal(Number(freeCollateral), 0.5 * 1e9);
  });

  it("SlashCollateral 0.2 Gwei to new account", async function () {
    const req = await this.CollateralTestWrapper.slashCollateral_public(
      this.vaultId,
      this.vaultId_new,
      0.2 * 1e9
    );

    const event = req.logs.filter((log) => log.event == "SlashCollateral")[0];

    assert.equal(event.args.sender, this.vaultId);
    assert.equal(event.args.amount, 0.2 * 1e9);
    assert.equal(event.args.receiver, this.vaultId_new);
  });

  it("after slash: totalCollateral equal 0.3 Gwei", async function () {
    const totalCollateral = await this.CollateralTestWrapper.TotalCollateral();
    assert.equal(Number(totalCollateral), 0.3 * 1e9);
  });

  it("after slash: 1Vault freeCollateral equal 0.3 Gwei", async function () {
    const freeCollateral =
      await this.CollateralTestWrapper.getFreeCollateral_public(this.vaultId);
    assert.equal(Number(freeCollateral), 0.3 * 1e9);
  });

  // it("after slash: 2Vault balance increased on 0.2 Gwei", async function () {
  //   const oldAmount = this.vaultId_new_initBalance;
  //   const newAmount = await web3.eth.getBalance(this.vaultId_new);
  //
  //   assert.equal(new BN(newAmount).sub(oldAmount), 0.2 * 1e9);
  // });
});
