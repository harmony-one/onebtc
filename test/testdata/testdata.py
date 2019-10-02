import subprocess
from subprocess import CalledProcessError
from os import path

import bitcoin.rpc
import simplejson as json
from bitcoin.core import *
from bitcoin.core.script import *
from bitcoin.wallet import *

DIRNAME = path.dirname(__file__)
FILENAME = path.join(DIRNAME, 'blocks.json')
BLOCKS = 10

bitcoin.SelectParams('regtest')

# Using RawProxy to avoid unwanted conversions
proxy = bitcoin.rpc.RawProxy()

# Generates a number of blocks
# @param number: number of blocks to generate
# returns number of block hashes
def generateBlocks(number):
    # setup address to generate blocks
    address_1 = proxy.getnewaddress()
    address_2 = proxy.getnewaddress()

    # generate first 101 blocks (maturation period + 1)
    proxy.generatetoaddress(101, address_1)

    # mine a number of blocks that include transactions
    blockhashes = []
    for i in range(number-1):
        # generate some transactions
        proxy.sendtoaddress(address_2, 10)
        # mine block with transaction and append to block hashes
        blockhashes.append(proxy.generatetoaddress(1, address_1)[0])
        # store blockhashes and tx hashes in that block
        # hashes.append({"blockhash": blockhash, "txhash": txhash})


    # only return blocks with more than 100 confirmations
    print("### Generated {} blocks with more than 100 confirmations ###".format(number))
    return blockhashes

    # send coins 
    # proxy.sendtoaddress(address2, 10)

    # blocks = []
    # for blockhash in list(blockhashes):
    #     # print(blockhash)
    #     blocks.append(proxy.getblockheader(blockhash))

# Exports the block headers to a JSON file
# @param blockhashes: 
def exportBlocks(blockhashes):
    # height = proxy.getblockcount()
    blocks = []
    for blockhash in blockhashes:
        block = proxy.getblock(blockhash) 

        txs = block["tx"]

        # queries the bitcoin-rpc gettxoutproof method
        # https://chainquery.com/bitcoin-cli/gettxoutproof#help
        # returns a raw proof consisting of the Merkle block
        # https://bitcoin.org/en/developer-reference#merkleblock
        proofs = []
        for i in range(len(txs)):
            # print("TX_INDEX {}".format(i))
            try:
                tx_id = txs[i]
                # print("TX {}".format(tx_id))
                output = subprocess.run(["bitcoin-cli", "-regtest", "gettxoutproof", str(json.dumps([tx_id])), blockhash], capture_output=True, check=True)

                proof = output.stdout.rstrip()
                # Proof is
                # 160 block header
                # 8 number of transactionSs
                # 2 no hashes
                number_hashes = int(proof[168:170], 16)

                merklePath = []
                for h in range(number_hashes):
                    start = 170 + 64*h
                    end = 170 + 64*(h+1)
                    hash = proof[start:end]
                    merklePath.append(hash)

                # print(merklePath)

                block["tx"][i] = {"tx_id": tx_id, "merklePath": merklePath, "tx_index": i}

            except CalledProcessError as e:
                print(e.stderr)
            

        blocks.append(block)



    with open(FILENAME, 'w', encoding='utf-8') as f:
        json.dump(blocks, f, ensure_ascii=False, indent=4)

    print("### Exported {} blocks to {} ###".format(len(blocks), FILENAME))


    # print("### Exported {} proofs to {} ###".format(len(txhashes),file))

    

if __name__ == "__main__":
    blockhashes = generateBlocks(BLOCKS)
    exportBlocks(blockhashes)
