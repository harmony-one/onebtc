# btc relayer

BTCRelayer is a daemon program working as the relayer of one trustless onebtc bridge.
Every bridge runner can start their own relayer program and provide service to end users.

It is a client of both Bitcoin and Harmony blockchains.
It can be regarded as the reference dApp of the trustless bridge smart contract.

It's main functions include:
 
+ periodically query the Bitcoin blockchain to retrieve the block header 
+ verify the blockheader 
+ calling the btcrelay smart contract to submit the block header to Harmony blockchain
+ generate tx inclusion proof that can be used to call btcrelay smart contract to prove the tx inclusion
