const BN = require("bn.js");
const { expectRevert } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const OneBtc = artifacts.require("OneBtc");
const RelayMock = artifacts.require("RelayMock");
const ExchangeRateOracleWrapper = artifacts.require("ExchangeRateOracleWrapper");
const { issueTxMock } = require('./mock/btcTxMock');

const bitcoin = require('bitcoinjs-lib');
const bn=b=>BigInt(`0x${b.toString('hex')}`);
const sleep = ms => new Promise(r => setTimeout(r, ms));

web3.extend({
    property: "miner",
    methods: [
      {
        name: "incTime",
        call: "evm_increaseTime",
        params: 1,
      },
      {
        name: "mine",
        call: "evm_mine",
        params: 0,
      },
    ],
  });

contract("liquidation test", accounts => {
    var relayMock;
    var exchangeRateOracleWrapper;
    var oneBtc;
    var issueRequester = accounts[2];
    var redeemRequester = accounts[3];
    var redeemBtcAddress;
    
    before(async function() {
        relayMock = await RelayMock.new();
        exchangeRateOracleWrapper = await deployProxy(ExchangeRateOracleWrapper);
        oneBtc = await deployProxy(OneBtc, [relayMock.address, exchangeRateOracleWrapper.address]);

        // set BTC/ONE exchange rate
        await exchangeRateOracleWrapper.setExchangeRate(10); // 1 OneBtc = 10 ONE

        // increase time to be enable exchange rate
        await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
        await web3.miner.mine();
        

        const ecPair = bitcoin.ECPair.makeRandom({compressed:false});
        const script = bitcoin.payments.p2pkh({pubkey:ecPair.publicKey})
        redeemBtcAddress = '0x'+script.hash.toString('hex');
    });

    async function issueToken(vaultId, IssueAmount) {
        const Collateral = await exchangeRateOracleWrapper.wrappedToCollateral(IssueAmount);
        const collateralForIssued = Collateral * 150 / 100;
        const griefingCollateral = collateralForIssued * 5 / 1000;
    
        const IssueReq = await oneBtc.requestIssue(IssueAmount, vaultId, {
          from: issueRequester,
          value: griefingCollateral,
        });
        const IssueEvent = IssueReq.logs.filter(
          (log) => log.event == "IssueRequested"
        )[0];
        const issueId = IssueEvent.args.issueId;
        const btcAddress = IssueEvent.args.btcAddress;
        const btcBase58 = bitcoin.address.toBase58Check(
          Buffer.from(btcAddress.slice(2), "hex"),
          0
        );
        const btcTx = issueTxMock(issueId, btcBase58, IssueAmount);
        const btcBlockNumberMock = 1000;
        const btcTxIndexMock = 2;
        const heightAndIndex = (btcBlockNumberMock << 32) | btcTxIndexMock;
        const headerMock = Buffer.alloc(0);
        const proofMock = Buffer.alloc(0);
        const outputIndexMock = 0;
        const ExecuteReq = await oneBtc.executeIssue(
          issueRequester,
          issueId,
          proofMock,
          btcTx.toBuffer(),
          heightAndIndex,
          headerMock,
          outputIndexMock
        );
        
        const ExecuteEvent = ExecuteReq.logs.filter(
          (log) => log.event == "IssueCompleted"
        )[0];
        assert.equal(ExecuteEvent.args.issuedId.toString(), issueId.toString());    
    }
    it("get liquidation ratio", async() => {
        const vaultId = accounts[1];
        const VaultEcPair = bitcoin.ECPair.makeRandom({compressed:false});
        const pubX = bn(VaultEcPair.publicKey.slice(1, 33));
        const pubY = bn(VaultEcPair.publicKey.slice(33, 65));
        const collateral = web3.utils.toWei('10');
        await oneBtc.registerVault(pubX, pubY, {from:vaultId, value: collateral});
        const vault = await oneBtc.vaults(vaultId);
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(pubX.toString(), vault.btcPublicKeyX.toString());
        assert.equal(collateral, vault.collateral.toString());
        let ratio = await oneBtc.liquidationRatio.call(vaultId);
        assert.equal(ratio.toString(), "0");

        // == 5 ONE x 1.5 = 7.5 => 7.5/10 => 75%
        const IssueAmount = 0.5 * 1e8;  
        await issueToken(vaultId, IssueAmount);
        ratio = await oneBtc.liquidationRatio.call(vaultId);
        assert.equal(ratio.toString(), "7500");
        await expectRevert(oneBtc.liquidateVaultUnderCollateralized(vaultId), "under");

        await exchangeRateOracleWrapper.setExchangeRate(15); // 1 OneBtc = 10 ONE

        // require delay to get the price
        await web3.miner.incTime(Number(1001)); // MAX_DELAY = 1000
        await web3.miner.mine();

        ratio = await oneBtc.liquidationRatio.call(vaultId);
        assert.equal(ratio.toString(), "11250");
        const vaultBefore = await oneBtc.vaults(vaultId);
        console.log(vaultBefore);

        await oneBtc.liquidateVaultUnderCollateralized(vaultId);
        
        const vaultAfter = await oneBtc.vaults(vaultId);
        console.log(vaultAfter);

    });
});