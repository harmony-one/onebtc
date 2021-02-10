import * as dotenv from 'dotenv';
dotenv.config();
const Ethers = require('ethers')

export let url: string
export let chainId: number
export let shardId: number = -1
if (process.env.SHARD != null) {
  shardId = parseInt(process.env.SHARD, 10)
}

/**
 *  All configs are for eth-type txs on the Harmony network.
 */
switch (process.env.NETWORK) {
  case 'testnet': {
    url = "https://rpc.s" + shardId + ".b.hmny.io"
    chainId = 1666700000 + shardId
    break;
  }
  case 'mainnet': {
    url = "https://rpc.s" + shardId + ".t.hmny.io"
    chainId = 1666600000 + shardId
    break;
  }
  default: {
    url = "http://localhost:950" + shardId + "/"
    chainId = 1666700000 + shardId
    break;
  }
}

let privateKey: string = ""
if (process.env.PRIVATE_KEY != null) {
  privateKey = process.env.PRIVATE_KEY
  if (!privateKey.startsWith("0x")) {
    privateKey = "0x" + privateKey
  }
}

export let HarmonyProvider = new Ethers.providers.JsonRpcProvider(url, {chainId: chainId})
export let HarmonyDeployWallet = new Ethers.Wallet(privateKey, HarmonyProvider)