async function main() {

  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  // We get the contract to deploy
  const CryptoHeadsNFT = await ethers.getContractFactory("CryptoHeadsNFT");
  const cryptoheadsNFT = await CryptoHeadsNFT.deploy();

  console.log("CryptoHeadsNFT deployed to:", cryptoheadsNFT.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
