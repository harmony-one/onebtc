const BTCRelay = artifacts.require("./BTCRelay.sol")
const BTCRelayAlt = artifacts.require("./BTCRelayAlt.sol")
const Utils = artifacts.require("./Utils.sol")

const constants = require("./constants")
const helpers = require('./helpers');
const truffleAssert = require('truffle-assertions');
const BigNumber = require('big-number');

var eventFired = helpers.eventFired;
var dblSha256Flip = helpers.dblSha256Flip
var flipBytes = helpers.flipBytes

contract('BTCRelay storeHeader', async(accounts) => {



    const submitter = accounts[0];

    // gas limit
    const gas_limit = 6000000;

    beforeEach('setup contract', async function (){ 
        relay = await BTCRelay.new();
        relayAlt = await BTCRelayAlt.new();
        utils = await Utils.deployed();
    });


    it("parse block header bytes", async () => {
        let parsedHeader = await relay.parseBlockHeader.call(
            constants.GENESIS.HEADER
        )
        assert.equal(parsedHeader.version.toNumber(), constants.GENESIS.HEADER_INFO.VERSION)
        assert.equal(parsedHeader.time.toNumber(), constants.GENESIS.HEADER_INFO.TIME)
        assert.equal(parsedHeader.nonce.toNumber(), constants.GENESIS.HEADER_INFO.NONCE)
        //assert.equal(new BigNumber(storedHeader.target), new BigNumber(constants.GENESIS.HEADER_INFO.TARGET))
        assert.equal(flipBytes(parsedHeader.merkleRoot), constants.GENESIS.HEADER_INFO.MERKLE_ROOT)
        assert.equal(parsedHeader.prevBlockHash, "0x0000000000000000000000000000000000000000000000000000000000000000")
    
    });
    
    it("set Genesis as initial parent ", async () => {   
        let submitHeaderTx = await relay.setInitialParent(
            constants.GENESIS.HEADER,
            constants.GENESIS.BLOCKHEIGHT,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
        // check if event was emmitted correctly
        truffleAssert.eventEmitted(submitHeaderTx, 'StoreHeader', (ev) => {
            return ev.blockHeight == 0;
        })

        //check header was stored correctly
        //TODO: check how to verify target - too large fpr toNumber() function 
        storedHeader = await relay.getBlockHeader.call(
            dblSha256Flip(constants.GENESIS.HEADER)
        )
        assert.equal(storedHeader.version.toNumber(), constants.GENESIS.HEADER_INFO.VERSION)
        assert.equal(storedHeader.time.toNumber(), constants.GENESIS.HEADER_INFO.TIME)
        assert.equal(storedHeader.nonce.toNumber(), constants.GENESIS.HEADER_INFO.NONCE)
        //assert.equal(new BigNumber(storedHeader.target), new BigNumber(constants.GENESIS.HEADER_INFO.TARGET))
        assert.equal(flipBytes(storedHeader.merkleRoot), constants.GENESIS.HEADER_INFO.MERKLE_ROOT)
        assert.equal(storedHeader.prevBlockHash, "0x0000000000000000000000000000000000000000000000000000000000000000")
    
        console.log("Gas used: " + submitHeaderTx.receipt.gasUsed)
    });
    

    it("Alternative: set Genesis as initial parent ", async () => {   
        let submitHeaderTx = await relayAlt.setInitialParent(
            constants.GENESIS.HEADER,
            constants.GENESIS.BLOCKHEIGHT,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
        // check if event was emmitted correctly
        truffleAssert.eventEmitted(submitHeaderTx, 'StoreHeader', (ev) => {
            return ev.blockHeight == 0;
        })

        //check header was stored correctly
        //TODO: check how to verify target - too large fpr toNumber() function 
        storedHeader = await relayAlt.getBlockHeader.call(
            dblSha256Flip(constants.GENESIS.HEADER)
        )
        assert.equal(storedHeader.version.toNumber(), constants.GENESIS.HEADER_INFO.VERSION)
        assert.equal(storedHeader.time.toNumber(), constants.GENESIS.HEADER_INFO.TIME)
        assert.equal(storedHeader.nonce.toNumber(), constants.GENESIS.HEADER_INFO.NONCE)
        //assert.equal(new BigNumber(storedHeader.target), new BigNumber(constants.GENESIS.HEADER_INFO.TARGET))
        assert.equal(flipBytes(storedHeader.merkleRoot), constants.GENESIS.HEADER_INFO.MERKLE_ROOT)
        assert.equal(storedHeader.prevBlockHash, "0x0000000000000000000000000000000000000000000000000000000000000000")
    
        console.log("Gas used: " + submitHeaderTx.receipt.gasUsed)
    });

    it("submit 1 block after initial Genesis parent ", async () => {   
        
        let submitGenesis = await relay.setInitialParent(
            constants.GENESIS.HEADER,
            constants.GENESIS.BLOCKHEIGHT,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
        truffleAssert.eventEmitted(submitGenesis, 'StoreHeader', (ev) => {
                return ev.blockHeight == 0;
        })        

        let submitBlock1 = await relay.storeBlockHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 1;
        });

        console.log("Total gas used: " + submitBlock1.receipt.gasUsed);
   });


   it("Alternative: submit 1 block after initial Genesis parent ", async () => {   
            
        let submitGenesis = await relayAlt.setInitialParent(
            constants.GENESIS.HEADER,
            constants.GENESIS.BLOCKHEIGHT,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
        truffleAssert.eventEmitted(submitGenesis, 'StoreHeader', (ev) => {
                return ev.blockHeight == 0;
        })        

        let submitBlock1 = await relayAlt.storeBlockHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 1;
        }); 
        console.log("Total gas used: " + submitBlock1.receipt.gasUsed);
    });


    it("submit 1 diff. adjust block after initial Genesis parent ", async () => {   
        
        let submitGenesis = await relay.setInitialParent(
            constants.GENESIS.HEADER,
            2015,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
        truffleAssert.eventEmitted(submitGenesis, 'StoreHeader', (ev) => {
                return ev.blockHeight == 2015;
        })        

        let submitBlock1 = await relay.storeBlockHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 2016;
        });

        console.log("Total gas used: " + submitBlock1.receipt.gasUsed);
   });


   it("Alternative: submit 1 diff. adjust block after initial Genesis parent ", async () => {   
            
        let submitGenesis = await relayAlt.setInitialParent(
            constants.GENESIS.HEADER,
            2015,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
        truffleAssert.eventEmitted(submitGenesis, 'StoreHeader', (ev) => {
                return ev.blockHeight == 2015;
        })        

        let submitBlock1 = await relayAlt.storeBlockHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 2016;
        }); 
        console.log("Total gas used: " + submitBlock1.receipt.gasUsed);
    });

})