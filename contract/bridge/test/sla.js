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

  it("deposit sla change - vault id : 4", async () => {
    await contractInstance.eventUpdateVaultSla(vaultId, 4, 60);
    const sla = await contractInstance.getVaultSla(vaultId);
    assert.equal(sla.toNumber(), 70);
  });

  it("withdraw sla change - vault id: 5", async () => {
    await contractInstance.eventUpdateVaultSla(vaultId, 5, 55);
    const sla = await contractInstance.getVaultSla(vaultId);
    assert.equal(sla.toNumber(), 90);
  });

  it("execute issue sla change - vault id: 3", async () => {
    await contractInstance.eventUpdateVaultSla(vaultId, 3, 25);
    const sla = await contractInstance.getVaultSla(vaultId);
    assert.equal(sla.toNumber(), 90);
  });

  it("deposit sla change - relayer id : 4", async () => {
    await contractInstance.eventUpdateRelayerSla(vaultId, 4, 60);
    const sla = await contractInstance.getRelayerSla(vaultId);
    assert.equal(sla.toNumber(), 50);
  });

  it("withdraw sla change - relayer id: 5", async () => {
    await contractInstance.eventUpdateRelayerSla(vaultId, 5, 55);
    const sla = await contractInstance.getRelayerSla(vaultId);
    assert.equal(sla.toNumber(), 70);
  });

  it("execute issue sla change - relayer id: 3", async () => {
    await contractInstance.eventUpdateRelayerSla(vaultId, 3, 25);
    const sla = await contractInstance.getRelayerSla(vaultId);
    assert.equal(sla.toNumber(), 70);
  });
});
