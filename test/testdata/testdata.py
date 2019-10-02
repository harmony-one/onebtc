from os import path

import bitcoin.rpc
import simplejson as json
from bitcoin.core import *
from bitcoin.core.script import *
from bitcoin.wallet import *

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

    # generate first 100 blocks (maturation period)
    proxy.generatetoaddress(100, address_1)

    # mine a number of blocks that include transactions
    blockhashes = proxy.generatetoaddress(1, address_1)
    for i in range(number-1):
        # generate some transactions
        proxy.sendtoaddress(address_2, 10)
        # mine block with transaction
        blockhashes.append(proxy.generatetoaddress(1, address_1)[0])


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
    block_headers = [proxy.getblock(hash) for hash in blockhashes]
    dirname = path.dirname(__file__)
    file = path.join(dirname, 'headers.json')

    with open(file, 'w', encoding='utf-8') as f:
        json.dump(block_headers, f, ensure_ascii=False, indent=4)

    print("### Exported {} block headers to {}".format(len(block_headers),file))


if __name__ == "__main__":
    blocks = 10
    hashes = generateBlocks(blocks)
    exportBlocks(hashes)
