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

  // const MarketPlace = "RANMarketPlace";
  // const MarketPlaceContract = await ethers.getContractFactory(MarketPlace);
  // const MarketPlaceDeployed = await MarketPlaceContract.deploy("0xf115cA1eC48B77EE031BE4d7E429244cC928d42B", "0x4A6D8c93815b6021ba3B2DE6B8145442E1A64302");

  // await MarketPlaceDeployed.deployed();
  // console.log(MarketPlace, " tx hash:", MarketPlaceDeployed.address); // 0x623b63d57b8D199F778dc97C1d0Ab612FCFe02D3

  // const Reviewer = "Reviewer";
  // const ReviewerContract = await ethers.getContractFactory(Reviewer);
  // const ReviewerDeployed = await ReviewerContract.deploy("0xf115cA1eC48B77EE031BE4d7E429244cC928d42B", "0x4A6D8c93815b6021ba3B2DE6B8145442E1A64302", 1);

  // await ReviewerDeployed.deployed();
  // console.log(Reviewer, " tx hash:", ReviewerDeployed.address); // 0xbB28943afF29Be40ABDBB479bc5D3B6c32DB88BC

  const CommunityDAO = "CommunityDAO";
  const CommunityDAOContract = await ethers.getContractFactory(CommunityDAO);
  const CommunityDAODeployed = await CommunityDAOContract.deploy("0xbB28943afF29Be40ABDBB479bc5D3B6c32DB88BC");

  await CommunityDAODeployed.deployed();
  console.log(CommunityDAO, " tx hash:", CommunityDAODeployed.address); // 0x61a1f0A576BDE23D3ff13842625C4eFF7b457136

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
