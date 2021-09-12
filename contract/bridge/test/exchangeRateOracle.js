const exchangeRate = artifacts.require("ExchangeRateOracle")

contract("ExchangeRateOracle",(account)=>{
    let contractInstance;
    before(()=>{
        contractInstance = await exchangeRate.new();
    })
    it("setExchangeRate()", async ()=>{
       await contractInstance.setExchangeRate("0x5B38Da6a701c568545dCfcB03FcB875f56beddC4",10);
       const exchangeRate = await contractInstance.getExchangeRate();

       assert.equal(exchangeRate, 10);
    })
    it("collateralToWrapped", ()=>{
        const rate = await contractInstance.collateralToWrapped(1000)
        assert.equal(rate, 100)
    })
    it("wrapped To collateral", ()=>{
        const rate = await contractInstance.wrappedToCollateral(1000)
        assert.equal(rate, 10000)
    })
})
