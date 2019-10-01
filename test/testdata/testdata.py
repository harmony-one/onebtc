import sys
import bitcoin.rpc
from bitcoin.core import *
from bitcoin.core.script import *
from bitcoin.wallet import *


bitcoin.SelectParams('regtest')

# Using RawProxy to avoid unwanted conversions
proxy = bitcoin.rpc.RawProxy()

blocks = []

address1 = proxy.getnewaddress()
address2 = proxy.getnewaddress()

# generate first 101 blocks (maturation period + 1)
blockhashes = proxy.generatetoaddress(101, address)

# send coins 
proxy.sendtoaddress(address2, 10)


for blockhash in list(blockhashes):
    print(blockhash)
    blocks.append(proxy.getblockheader(blockhash))




def exportBlocks():
    height = proxy.getblockcount()

print(blocks[100])