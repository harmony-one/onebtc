const StakedRelayers = artifacts.require("StakedRelayers");
const { expectRevert, constants } = require("@openzeppelin/test-helpers");

contract("StakeRelayersTest", accounts => {
  it("registerStakedRelayer test", async () => {
    const instance = await StakedRelayers.new();
    await expectRevert(instance.registerStakedRelayer.call([constants.ZERO_ADDRESS, 1], 5), "Insufficient stake provided");
  });
});
