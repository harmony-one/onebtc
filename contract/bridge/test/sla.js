const SLA = artifacts.require("SLA");

contract("SLA", (account) => {
  let contractInstance;
  before(async () => {
    contractInstance = await SLA.new();
  });
  it("_depositSlaChange()", async () => {
    await contractInstance._depositSlaChange(10);
    const SLA = await contractInstance.getSLA();

    assert.equal(SLA, 10);
  });
  it("collateralToWrapped", async () => {
    const rate = await contractInstance.collateralToWrapped(1000);
    assert.equal(rate, 100);
  });
  it("wrapped To collateral", async () => {
    const rate = await contractInstance.wrappedToCollateral(1000);
    assert.equal(rate, 10000);
  });
});
