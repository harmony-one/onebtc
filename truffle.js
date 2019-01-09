var HDWalletProvider = require("truffle-hdwallet-provider");

var infura_apikey = "xxx";
var mnemonic = "xxx";

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*" // Match any network id
    },
    ropsten: {
      network_id: 3,
      provider: new HDWalletProvider(mnemonic, "https://ropsten.infura.io/" + infura_apikey),
      gas: 5800000
    },
    geth: {
      host: "localhost",
      port: 8545,
      gas: 5800000
    }
  },
  mocha: {
    enableTimeouts: false,
    useColors: true
  }
};