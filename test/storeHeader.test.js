const BTCRelay = artifacts.require("./BTCRelay.sol")
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
    const gas_limit = 8000000;

    const deploy = async function(){
        relay = await BTCRelay.new();
        utils = await Utils.deployed();
    }

    const storeGenesis = async function(){
        await relay.setInitialParent(
            constants.GENESIS.HEADER,
            constants.GENESIS.BLOCKHEIGHT,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
    }
    beforeEach('(re)deploy contracts', async function (){ 
        deploy()
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
        //TODO: check how to verify target - too large for toNumber() function 
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
    
    it("set duplicate initial parent - should fail", async () => {   
        storeGenesis();

        await truffleAssert.reverts(
            relay.setInitialParent(
                constants.GENESIS.HEADER,
                constants.GENESIS.BLOCKHEIGHT,
                constants.GENESIS.CHAINWORK,
                constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
                ),
                constants.ERROR_CODES.ERR_GENESIS_SET
            );
    });

    it("submit 1 block after initial Genesis parent ", async () => {   
        
        storeGenesis();
        let submitBlock1 = await relay.submitMainChainHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 1;
        });

        console.log("Total gas used: " + submitBlock1.receipt.gasUsed);
   });

   it("submit genesis, skips block 1, submits block 2 - should fail", async () => {   
        
    storeGenesis();       
    await truffleAssert.reverts(
        relay.submitMainChainHeader(
            constants.HEADERS.BLOCK_2
            ),
            constants.ERROR_CODES.ERR_PREV_BLOCK
        );
    });

    it("submit block 1 with invalid pow - should fail", async () => {   
        
        storeGenesis();     
        await truffleAssert.reverts(
            relay.submitMainChainHeader(
                constants.HEADERS.BLOCK_1_INVALID_POW
                ),
                constants.ERROR_CODES.ERR_LOW_DIFF
            );
    });

    it("submit duplicate block header (block 1) - should fail", async () => {   
    
        storeGenesis();    
        let submitBlock1 = await relay.submitMainChainHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 1;
        });   
        await truffleAssert.reverts(
            relay.submitMainChainHeader(
                constants.HEADERS.BLOCK_1
                ),
                constants.ERROR_CODES.ERR_DUPLICATE_BLOCK
            );
    });

    it("submit main chain block as fork - should fail", async () => {   
    
        storeGenesis();    
        let submitBlock1 = await relay.submitMainChainHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 1;
        });   
        //TODO: need correct fork data
    });
        
    it("submit 1 diff. adjust block after initial Genesis parent ", async () => {   
        
        storeGenesis();      

        let submitBlock1 = await relay.submitMainChainHeader(
            constants.HEADERS.BLOCK_1
        );
        truffleAssert.eventEmitted(submitBlock1, 'StoreHeader', (ev) => {
            return ev.blockHeight == 2016;
        });

        console.log("Total gas used: " + submitBlock1.receipt.gasUsed);
   });

})