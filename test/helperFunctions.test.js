

const BTCRelay = artifacts.require("./BTCRelay.sol")
const Utils = artifacts.require("./Utils.sol")

contract('BTCRelay helpfer functions', async(accounts) => {

    const submitter = accounts[0];

    // gas limit
    const gas_limit = 6000000;

    const BLOCKHEIGHT = 201600;
    const BLOCKHASH = "0x00000000000003a5e28bef30ad31f1f9be706e91ae9dda54179a95c9f9cd9ad0";
    const MERKLE_TREE_ROOT = "0x93fead0c2477030367d63c91854e7eea0cacdfc4e28ffeae4d7c5cbb17933925";
    const TIME = 1349226660;
    const TARGET = 1;
    const CHAINWORK = 1;
    beforeEach('setup contract', async function (){ 
        relay = await BTCRelay.deployed();
        utils = await Utils.deployed();
    });


    it('flipBytes LE to BE', async () => {
        // should convert LE to BE representation        
        let convert_le_be = await utils.flipBytes('0x0123456789abcdef');
        assert.equal(convert_le_be, '0xefcdab8967452301');
    });
})