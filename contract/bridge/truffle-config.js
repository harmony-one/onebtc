/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

// const mnemonic = "clean rail tag stem vital kite scatter common few rely cattle nice";

module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    test: {
      host: "localhost",
      port: 9545,
      network_id: "5777",
      // gas: 4712388
      // host: "127.0.0.1",
      // port: 8545,
      // network_id: '*',
    },

    local: {
      host: "localhost",
      port: 7545,
      network_id: "5777",
      // gas: 4712388
      // host: "127.0.0.1",
      // port: 8545,
      // network_id: '*',
      accounts: 5,
      defaultEtherBalance: 500,
      blockTime: 0,
    },

    develop: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      accounts: 5,
      defaultEtherBalance: 500,
      blockTime: 0,
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 20000000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.12+commit.27d51765", // Fetch exact version from solc-bin (default: truffle's version)
      settings: {
        // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200,
        },
      //  evmVersion: "byzantium"
      }
    }
  },
  plugins: [
    'truffle-contract-size'
  ]
};
