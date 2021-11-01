const SLA = artifacts.require("SLAWrapper");

contract("SLA", (account) => {
  let contractInstance;
  const vaultId = account[3];

  before(async () => {
    contractInstance = await SLA.new(100, 100, 10, 10, 10, 20, 20, 20, 20);
  });

  it("get functions working correctly and setting up vaultSla values for tests", async () => {
    assert.equal(await contractInstance.getRelayerSla(vaultId), 0);
    assert.equal(await contractInstance.getVaultSla(vaultId), 0);

    await contractInstance.setVaultSla(vaultId, 50);
    await contractInstance.setRelayerSla(vaultId, 30);

    assert.equal(await contractInstance.getRelayerSla(vaultId), 30);
    assert.equal(await contractInstance.getVaultSla(vaultId), 50);
  });

  it("_depositSlaChange()", async () => {
    await contractInstance.depositSlaChange(10);
    const SLA = await contractInstance.getSLA();

    assert.equal(SLA, 10);
  });
});
