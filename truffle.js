const HDWalletProvider = require('truffle-hdwallet-provider');
const mnemonic = 'window change anchor level infant fine inside multiply spirit left slight evoke';

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
    rinkeby: {
      provider: function() {
        return new HDWalletProvider(mnemonic, 'https://rinkeby.infura.io/v3/4528acb6d57d4bbb8fd0caa204e66464');
      },
      network_id: 4
    }
  },
  compilers: {
    solc: {
      version: "0.5.2" // ex:  "0.4.20". (Default: Truffle's installed solc)
    }
  }
};
