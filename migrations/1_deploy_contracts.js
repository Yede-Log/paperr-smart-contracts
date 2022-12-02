const CommunityDAO = artifacts.require("CommunityDAO");
const Reviewer = artifacts.require("Reviewer");
const MarketPlace = artifacts.require("RANMarketPlace");
const ReviewerToken = artifacts.require("ReviewerToken");
const ReviewedAssetNFT = artifacts.require("ReviewedAssetNFT");

module.exports = function(deployer) {
    // deployer.deploy(CommunityDAO, "0x69015912AA33720b842dCD6aC059Ed623F28d9f7");
    // deployer.deploy(ReviewerToken, 10000000);
    // deployer.deploy(ReviewedAssetNFT);
    deployer.deploy(
        Reviewer,
        "0x906D3BfF148D294cDDd78615DC235CD8b7121c5e",
        "0x6c318b50f5Dd4A1498DcEB3930CE8A545d736898",
        "0x0000000000000000000000000000000000000000",
        1
    );
};