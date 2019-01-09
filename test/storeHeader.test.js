const BTCRelay = artifacts.require("./BTCRelay.sol")
const Utils = artifacts.require("./Utils.sol")

const constants = require("./constants")
const helpers = require('./helpers');

var eventFired = helpers.eventFired;

contract('BTCRelay storeHeader', async(accounts) => {



    const submitter = accounts[0];

    // gas limit
    const gas_limit = 6000000;

    
    beforeEach('setup contract', async function (){ 
        relay = await BTCRelay.deployed();
    });


    beforeEach('setup contract', async function (){ 
        relay = await BTCRelay.deployed();
        utils = await Utils.deployed();
    });

    it("set Genesis as initial parent ", async () => {   
         let submitHeaderTx = await relay.setInitialParent(
             constants.GENESIS.HEADER,
             constants.GENESIS.BLOCKHEIGHT,
             constants.GENESIS.CHAINWORK,
             constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
             );
         eventFired(submitHeaderTx, "StoreHeader", (ev) => {
             return ev.returnCode == 0;
         })
    });


    it("submit block 1 after initial Genesis parent ", async () => {   
        let submitGenesis = await relay.setInitialParent(
            constants.GENESIS.HEADER,
            constants.GENESIS.BLOCKHEIGHT,
            constants.GENESIS.CHAINWORK,
            constants.GENESIS.LAST_DIFFICULTY_ADJUSTMENT_TIME
            );
        eventFired(submitGenesis, "StoreHeader", (ev) => {
            return ev.returnCode == 0;
        })

        let submitBlock1 = await relay.storeBlockHeader(
            constants.HEADERS.BLOCK_1
        )
        eventFired(submitGenesis, "StoreHeader", (ev) => {
            return ev.returnCode == 1;
        })
   });
})