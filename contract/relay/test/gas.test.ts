import chai from "chai";
import { deployContract, solidity } from "ethereum-waffle";
import RelayArtifact from "../artifacts/Relay.json";
import { Relay } from "../typechain/Relay"
import { HarmonyDeployWallet, HarmonyTransactionOverrides } from "../scripts/hmy_config";
import { WaitForNextBlocks } from "./util";

chai.use(solidity);
const { expect } = chai;

describe("Gas", () => {
  afterEach(async () => {
    await WaitForNextBlocks(1)
  })

  let relay: Relay;
  let genesisHeader = "0x00000020db62962b5989325f30f357762ae456b2ec340432278e14000000000000000000d1dd4e30908c361dfeabfb1e560281c1a270bde3c8719dbda7c848005317594440bf615c886f2e17bd6b082d";
  let genesisHash = "0x4615614beedb06491a82e78b38eb6650e29116cc9cce21000000000000000000";
  let genesisHeight = 562621;

  // 562622
  let header1 = "0x000000204615614beedb06491a82e78b38eb6650e29116cc9cce21000000000000000000b034884fc285ff1acc861af67be0d87f5a610daa459d75a58503a01febcc287a34c0615c886f2e17046e7325";

  it("should deploy at minimal cost", async () => {
    relay = await deployContract(
      HarmonyDeployWallet, RelayArtifact, [genesisHeader, genesisHeight], HarmonyTransactionOverrides,
    ) as Relay;
    let deployCost = (await relay.deployTransaction.wait(1)).gasUsed?.toNumber();
    expect(deployCost).to.not.eq(null)
    if (deployCost != null) {
      let deployCostInOne = deployCost * 1e-18
      console.log(`Deploy Cost: ${deployCostInOne} ONE (${deployCost} ATTO)`);
    }
    expect(deployCost).to.be.lt(1_900_000);
  })

  it("should submit a block at minimal cost", async () => {
    let result = await relay.submitBlockHeader(header1);
    let updateCost = (await result.wait(1)).gasUsed?.toNumber();
    expect(updateCost).to.not.eq(null)
    if (updateCost != null) {
      let updateInOne = updateCost * 1e-18
      console.log(`Update Cost: ${updateInOne} ONE (${updateCost} ATTO)`);
    }
    expect(updateCost).to.be.lt(120_000);
  })
});