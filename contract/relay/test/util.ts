import {HarmonyProvider} from "../scripts/config";

export const ErrorCode = {
  ERR_INVALID_HEADER_SIZE: "Invalid block header size",
  ERR_DUPLICATE_BLOCK: "Block already stored",
  ERR_PREVIOUS_BLOCK: "Previous block hash not found",
  ERR_LOW_DIFFICULTY: "Insufficient difficulty",
  ERR_DIFF_TARGET_HEADER: "Incorrect difficulty target",
  ERR_DIFF_PERIOD: "Invalid difficulty period",
  ERR_NOT_EXTENSION: "Not extension of chain",
  ERR_BLOCK_NOT_FOUND: "Block not found",
  ERR_CONFIRMS: "Insufficient confirmations",
  ERR_VERIFY_TX: "Incorrect merkle proof",
  ERR_INVALID_TXID: "Invalid tx identifier",
}

/**
 *
 * Wait for the specified number of blocks before resolving.
 *
 * @param numberOfBlocks to wait for.
 */
export async function WaitForNextBlocks(numberOfBlocks: number) {
  let startingBlock = await HarmonyProvider.getBlockNumber()
  while (true) {
    let currBlock = await HarmonyProvider.getBlockNumber()
    if (currBlock > startingBlock + numberOfBlocks) {
      return
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }
}
