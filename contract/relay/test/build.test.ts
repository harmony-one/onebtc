import chai from "chai";
import { Contract } from "ethers";
import { solidity } from "ethereum-waffle";
import { genesis, generate } from "../scripts/builder";
import { DeployTestRelay } from "../scripts/contracts";
import { HarmonyDeployWallet } from "../scripts/config";
import { WaitForNextBlocks } from "./util";
import {beforeEach} from "mocha";

chai.use(solidity);
const { expect } = chai;

describe("Build", () => {
    beforeEach(async () => {
        await WaitForNextBlocks(1)
    })

    let block = genesis();
    let contract : Contract

    describe("genesis", () => {
      it("should deploy and init", async () => {
          block = genesis();
          contract = await DeployTestRelay(HarmonyDeployWallet, {
              header: '0x' + block.toHex(true),
              height: 1,
          });
      })
    })

    describe("block 1", () => {
        it("should submit", async () => {
            block = generate("bcrt1qu96jmjrfgpdynvqvljgszzm9vtzp7czquzcu6q", block.getHash());
            contract.submitBlockHeader('0x' + block.toHex(true))
        })
    })

    describe("best block", () => {
        it("should be block 1 hash", async () => {
            let best = await contract.getBestBlock();
            expect(best.digest).to.eq("0x9588627a4b509674b5ed7180cb2f9c8679fe5f1c8a6378069af0f2b8c2ff831f");
        })
    })

    describe("block 2", () => {
        it("should submit", async () => {
            block = generate("bcrt1qu96jmjrfgpdynvqvljgszzm9vtzp7czquzcu6q", block.getHash());
            contract.submitBlockHeader('0x' + block.toHex(true))
        })
    })

    describe("best block", () => {
        it("should be block 2 hash", async () => {
            let best = await contract.getBestBlock();
            expect(best.digest).to.eq("0x7b02735fdcd34c70e65d1442949bd0a0fae69aedabfc05503f3ae5998a8f4348");
        })
    })
});