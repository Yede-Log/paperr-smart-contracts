const CommunityDAO = artifacts.require("CommunityDAO");

module.exports = function(deployer) {
    deployer.deploy(CommunityDAO, "0x69015912AA33720b842dCD6aC059Ed623F28d9f7");
};