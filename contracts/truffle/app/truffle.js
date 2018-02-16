module.exports = {
  networks: {
    development: {
      host: process.env.HOST || "localhost",
      port: 8545,
      network_id: 58545,
      gas: 4712388, // Gas limit used for deploys
      //gasPrice: 21000000000000000000
    },
    rinkeby: {
      host: process.env.HOST || "localhost",
      port: 8545,
      network_id: 4,
      gas: 4712388, // Gas limit used for deploys
      from: '0x49b7776ea56080439000fd54c45d72d3ac213020'
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  },
  mocha: {
    useColors: true
  }
};
