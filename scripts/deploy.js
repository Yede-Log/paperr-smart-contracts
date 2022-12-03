async function main() {
  // const ReviewerTokenContract = "ReviewerToken";
  // const verifierName = "ReviewerToken";
  // const verifierSymbol = "RWT";
  // const ReviewerToken = await ethers.getContractFactory(ReviewerTokenContract);
  // const ReviewerTokenDeployed = await ReviewerToken.deploy(10000000, 100);

  // await ReviewerTokenDeployed.deployed();
  // console.log(verifierName, " tx hash:", ReviewerTokenDeployed.address); // 0xf115cA1eC48B77EE031BE4d7E429244cC928d42B

  // const ReviewedAssetNFTContractName = "ReviewedAssetNFT";
  // const ReviewedAssetNFTContract = await ethers.getContractFactory(ReviewedAssetNFTContractName);
  // const ReviewedAssetNFTContractDeployed = await ReviewedAssetNFTContract.deploy();

  // await ReviewedAssetNFTContractDeployed.deployed();
  // console.log(ReviewedAssetNFTContractName, " tx hash:", ReviewedAssetNFTContractDeployed.address); // 0x4A6D8c93815b6021ba3B2DE6B8145442E1A64302

  const CommunityDAO = "CommunityDAO";
  const CommunityDAOContract = await ethers.getContractFactory(CommunityDAO);
  const CommunityDAODeployed = await CommunityDAOContract.deploy("0x0000000000000000000000000000000000000000");

  await CommunityDAODeployed.deployed();
  console.log(CommunityDAO, " tx hash:", CommunityDAODeployed.address); // 0x61a1f0A576BDE23D3ff13842625C4eFF7b457136

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
