import subprocess
from subprocess import CalledProcessError
from os import path

import bitcoin.rpc
import simplejson as json
from bitcoin.core import *
from bitcoin.core.script import *
from bitcoin.wallet import *

dirname = path.dirname(__file__)

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
    txhashes = []
    for i in range(number-1):
        # generate some transactions
        tx_hash = [proxy.sendtoaddress(address_2, 10)]
        # mine block with transaction
        blockhash = proxy.generatetoaddress(1, address_1)[0]
        blockhashes.append(blockhash)
        # store blockhashes and tx hashes in that block
        txhashes.append({"blockhash": blockhash, "tx_hash": tx_hash})


    # only return blocks with more than 100 confirmations
    print("### Generated {} blocks with more than 100 confirmations ###".format(number))
    return blockhashes, txhashes

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
    block_headers = [proxy.getblock(hash) for hash in blockhashes]

    file = path.join(dirname, 'headers.json')

    with open(file, 'w', encoding='utf-8') as f:
        json.dump(block_headers, f, ensure_ascii=False, indent=4)

    print("### Exported {} block headers to {} ###".format(len(block_headers),file))

def exportTxProofs(txhashes):
    # queries the bitcoin-rpc gettxoutproof method
    # https://chainquery.com/bitcoin-cli/gettxoutproof#help
    # returns a raw proof consisting of the Merkle block
    # https://bitcoin.org/en/developer-reference#merkleblock
    proofs = []
    for tx in txhashes:
        try:
            blockhash = tx["blockhash"]
            txhash = tx["tx_hash"]

            output = subprocess.run(["bitcoin-cli", "-regtest", "gettxoutproof", str(json.dumps(txhash)), blockhash], capture_output=True, check=True)

            proofs.append(output.stdout)
        
        except CalledProcessError as e:
            print(e.stderr)


    # stores the tx proof in the format for BTC relay for verifyTx function
    # txid: bytes32
    # txBlockHeight: uint256
    # txIndex: unit256
    # merkleProof: bytes
    # confirmations: uint256 

    # export data to JSON
    file = path.join(dirname, 'transactions.json')
    with open(file, 'w', encoding='utf-8') as f:
        json.dump(proofs, f, ensure_ascii=False, indent=4)

    print("### Exported {} proofs to {} ###".format(len(txhashes),file))

    

if __name__ == "__main__":
    blocks = 10
    blockhashes, txhashes = generateBlocks(blocks)
    exportBlocks(blockhashes)
    exportTxProofs(txhashes)
