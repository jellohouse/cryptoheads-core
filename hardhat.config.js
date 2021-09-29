require("@nomiclabs/hardhat-waffle");


task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});



const INFURA_PROJECT_ID = "d23aae1a4a91493f833abd2a7ce0f7e5"
const METAMASK_PRIVATE_KEY = "a31e6165139b3c9c364a5dbf94dad722cdddbcdce7a1ff15678420ae66cde62e"


module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      // {
      //   version: "0.7.6",
      //   settings: {
      //     optimizer: {
      //       enabled: true,
      //       runs: 200
      //     }
      //   }
      // },
    ]
  },
  networks: {
    goerli: {
       url: `https://goerli.infura.io/v3/${INFURA_PROJECT_ID}`,
       accounts: [`0x${METAMASK_PRIVATE_KEY}`] ,
    },
  },
};
