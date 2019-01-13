var BTCRelayAlt = artifacts.require("./BTCRelayAlt.sol");
var Utils = artifacts.require("./Utils.sol")

module.exports = function (deployer, network) {
    if (network == "development") {
        deployer.deploy(Utils);
        deployer.link(Utils, BTCRelayAlt);
        deployer.deploy(BTCRelayAlt);
    } else if (network == "ropsten") {
        deployer.deploy(BTCRelayAlt);
    } else if (network == "main") {
        deployer.deploy(BTCRelayAlt);
    }
};
