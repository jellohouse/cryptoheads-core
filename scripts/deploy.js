async function main() {

  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());



  // We get the contract to deploy

  // const CryptoHeadsNFT = await ethers.getContractFactory("CryptoHeadsNFT");
  // const cryptoheadsNFT = await CryptoHeadsNFT.deploy('0xd8Cd47263414aFEca62d6e2a3917d6600abDceB3');
  // console.log("CryptoHeadsNFT deployed to:", cryptoheadsNFT.address);




  const RocketPool_TEST = await ethers.getContractFactory("RocketPool_TEST");
  const rocketTEST = await RocketPool_TEST.deploy('0xd8Cd47263414aFEca62d6e2a3917d6600abDceB3');
  console.log("RocketPool_TEST deployed to:", rocketTEST.address);


}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
