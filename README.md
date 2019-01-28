# BTCRelay implementation in Solidity

**Disclaimer: this project is still under development and not safe to use!** 

## Chain Relays
Chain relays are on-chain programs or <i>smart contracts</i> deployed on a blockchain <i>A</i> capable of reading and verifying the state of another blockchain <i>B</i>. 
The underlying technical design and functionality is comparable to that of SPV-Clients. That is, a chain relay stores and maintains block headers of chain B on chain A and allows to verify transaction inclusion proofs. Summarizing, the two main functionalities a chain relay must/should provide are: <i>consensus verification</i> and <i>transaction inclusion verification</i>.

Read more about chain relays in the <a href="https://eprint.iacr.org/2018/643.pdf">XCLAIM paper</a> (Section V.B descibes the basic concept of chain relays, while Appendix B provides a formal model of the required functionality for PoW chain relays.).  

## BTCRelay-Sol
BTCRelay-Sol is an implementation of a chain relay for Bitcoin on Ethereum. The first implementation of BTCRelay was implemented in Serpent and can be found <a href="https://github.com/ethereum/btcrelay">here</a>. 
However, as Serpent is outdated (last commit: December 2017), this projects aims to implement an updated version in Solidity. 

### Design
The current implementation is based on the existing Serpent implementation, specifically with regards for fork handling. 
As such, BTCRelay must store all block headers to establish, whether a transaction is included in the Bitcoin main chain.
However, improved proofing techniques, such as <a href="https://nipopows.com/">NiPoPoWs</a> and <a href="https://scalingbitcoin.org/stanford2017/Day1/flyclientscalingbitcoin.pptx.pdf">FlyClient</a>, allow to reduce the storage requirements. Furthermore, protocols based on off-chain verification games such as <a href="https://truebit.io/">Truebit</a> may allow optimistic improvements to performance and cost. 

To this end, BTCRelay will be split into multiple components, allowing integration with the above mentioned verification techniques:
+ **Block header storage** ... sole functionality of this component is the efficient storage of block headers submitted to the telay
+ **Block header verification** ... performs verification of block headers before they are persisted, e.g. checks if the correct difficulty was set, verifies the hash pre-image, makes sure the pervious block header exists (or determines that a specific verification techniques is being used - see below), etc. 
+ **Main chain detection** ... the verification of the Bitcoin main chain (i.e., if a block is in the main chain or part of a fork) can be handled by (i) traversing all block headers as in the case of classic SPV verification, (ii) NiPoPoWs and FlyClient, (iii) off-chain verification games such as Truebit. 
+ **Transaction inclusion verification and parsing** ... calls one of the available methods of the main chain detection component and provides tools for parsing transaction inputs/outputs and performing validity checks. 


We note that the block header data used for testing was first provided in the BTCRelay Serpent implementation (<a href="https://github.com/ethereum/btcrelay">repo</a>).  

## Other resources
We make note of the following libraries/implementations, which specifically may aid with Bitcoin transaction parsing:
+ https://github.com/summa-tx/bitcoin-spv
+ https://github.com/tjade273/BTCRelay-tools
+ https://github.com/rainbreak/solidity-btc-parser
+ https://github.com/ethers/bitcoin-proof
+ https://github.com/ethers/EthereumBitcoinSwap 
+ 
## Installation

Make sure ganache-cli and truffle are installed as global packages. Then, install the required packages with:

```
npm install
```

## Testing

Start ganache:

```
ganache-cli
```

Migrate contracts:

```
truffle migrate
```

Run tests: 

```
truffle test
```
This will also re-run migration scripts. 
