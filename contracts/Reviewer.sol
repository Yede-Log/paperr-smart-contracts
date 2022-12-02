// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./CommunityDAO.sol";
import "./ReviewerToken.sol";
import "./ReviewedAssetNFT.sol";
import "@opengsn/contracts/src/ERC2771Recipient.sol";

contract Reviewer {

	address payable owner;
	uint256 public dev_fee;
	address public erc20_token;
	address public erc721_token;
	address public trustedForwarder;
	uint256 public reviews_required;
	uint256 public minimum_asset_creation_fee;

	mapping(string => Asset) assets;
	mapping(address => bool) verified_communities;

	struct Review {
		uint8 rating;
		string metadata;
		address payable reviewer;
		address reviewer_community;
	}
	
	struct Asset {
		Review[] reviews;
		uint256 avg_rating;
		address payable author;
		uint256 asset_creation_fee_payable;
		mapping (address => bool) reviewers;
		uint256 cummulative_reviewer_credibility;
		mapping (address => bool) reviewing_communities;
	}

	event DevFeeUpdated(uint256 dev_fee);
	event VerifiedCommunity(address community);
	event ReviewsRequiredUpdated(uint256 reviews_required);
	event MinimumAssetCreationFeeUpdated(uint256 minimum_asset_creation_fee);

	event AssetCreated(
		address owner,
		string metadata,
		uint256 asset_creation_fee_payable,
		address[] reviewing_communities
	);

	event AssetReviewed(
		uint8 rating,
		string metadata,
		address reviewer,
		address community,
		string review_metadata
	);

	constructor(
		address _erc20_tokenAddress,
		address _erc721_tokenAddress,
		address _trustedForwarder,
		uint256 _reviews_required
	) {
		owner = payable(msg.sender);
		erc20_token = _erc20_tokenAddress;
		erc721_token = _erc721_tokenAddress;
		trustedForwarder = _trustedForwarder;
		reviews_required = _reviews_required;
	}

	modifier onlyOwner() {
		require(msg.sender == owner, "Signer: needs to be owner of smart contract");
		_;
	}

	modifier onlyMarketPlace() {
		_;
	}

	function abs(int x) private pure returns (int) {
    	return x >= 0 ? x : -x;
	}

	function setDevFee(uint256 _dev_fee) public onlyOwner {
		dev_fee = _dev_fee;
		emit DevFeeUpdated(dev_fee);
	}

	function setReviewsRequired(uint256 _reviews_required) public onlyOwner {
		require(_reviews_required > 0, "Invalid Argument: new reviews required cannot be 0");
		reviews_required = _reviews_required;
		emit ReviewsRequiredUpdated(reviews_required);
	}

	function setMinimumAssetCreationFee(uint256 _minimum_asset_creation_fee) public onlyOwner {
		require(_minimum_asset_creation_fee > 0, "Invalid Argument: _minimum_asset_creation_fee cannot be 0");
		minimum_asset_creation_fee = _minimum_asset_creation_fee;
		emit MinimumAssetCreationFeeUpdated(minimum_asset_creation_fee);
	}

	function addVerifiedCommunity(address community) public onlyOwner {
		require(community != address(0), "Invalid Argument: community address cannot be burn address");
		verified_communities[community] = true;
		emit VerifiedCommunity(community);
	}

	function setCredibility(string memory tokenURI, uint8 rating) public onlyMarketPlace{
		Asset storage asset = assets[tokenURI];
		for (uint256 index = 0; index < asset.reviews.length; index++) {
			Review storage review = asset.reviews[index];
			
			uint8 diff = 0;
			if (review.rating > rating) diff = review.rating - rating; 
			else diff = rating - review.rating;
			
			if (diff > 3) CommunityDAO(review.reviewer_community).setCredibility(review.reviewer, diff, false);
			else CommunityDAO(review.reviewer_community).setCredibility(review.reviewer, diff, true);
		}
	}

	function createAsset(
		string memory metadata,
		uint8 v, bytes32 r, bytes32 s,
		uint256 asset_creation_fee_payable,
		address[] memory reviewing_communities
	) public returns(string memory) {
		require(bytes(metadata).length > 0, "Invalid Argument: _metadata cannot be empty string");
		require(
			reviewing_communities.length > 0,
			"Invalid Argument: atleast 1 _reviewing_community is required"
		);
		require(
			asset_creation_fee_payable > minimum_asset_creation_fee,
			"Invalid Argument: asset creation fee should be greater than minimum fee payable"
		);
		Asset storage asset = assets[metadata];
		asset.author = payable(msg.sender);
		for (uint256 index = 0; index < reviewing_communities.length; index++) {
			require(verified_communities[reviewing_communities[index]], "Community: Unverified community provided.");
			asset.reviewing_communities[reviewing_communities[index]] = true;
		}

		ReviewerToken RWToken = ReviewerToken(erc20_token);
		ReviewedAssetNFT RANToken = ReviewedAssetNFT(erc721_token);
		RWToken.permit(msg.sender, address(this), asset_creation_fee_payable, block.number + 15, v, r, s);
		RWToken.transferFrom(msg.sender, address(this), asset_creation_fee_payable);
		RANToken.mintAsset(msg.sender, metadata);

		emit AssetCreated(msg.sender, metadata, asset_creation_fee_payable, reviewing_communities);
		return metadata;
	}

	function reviewAsset(
		uint8 rating,
		address community,
		string memory metadata,
		string memory review_metadata
	) public returns(uint8) {
		Asset storage asset = assets[metadata];
		require(
		keccak256(abi.encodePacked(metadata)) != keccak256(abi.encodePacked(review_metadata)),
		"Invalid Argument: asset metadata string should not be equal to review metadata string"
		);
		require(rating > 0, "Invalid Argument: asset rating should be greater than 0");   
		require(asset.reviews.length <= reviews_required, "Review: asset has already been reviewed");
		require(!asset.reviewers[msg.sender], "Review: reviewer has already reviewed");
		require(asset.author != address(0), "Asset: does not exist");
		require(asset.reviewing_communities[community], "Asset: community is not allowed to review");
		require(CommunityDAO(community).isMember(payable(msg.sender)), "Review: reviewer is not member of community");

		Review memory review = Review(rating, review_metadata, payable(msg.sender), community);
		ERC20Permit RWToken = ERC20Permit(erc20_token);

		uint256 reviewer_credibility = CommunityDAO(community).credibility(msg.sender);

		asset.reviewers[msg.sender] = true;
		asset.reviews.push(review);
		
		asset.avg_rating = (
		(asset.avg_rating * asset.cummulative_reviewer_credibility) + (review.rating * reviewer_credibility)
		) / (asset.cummulative_reviewer_credibility + reviewer_credibility);
		asset.cummulative_reviewer_credibility += reviewer_credibility; 

		if(asset.reviews.length >= reviews_required) {
		uint256 asset_review_fee = (asset.asset_creation_fee_payable - dev_fee) / reviews_required;
			for (uint256 index = 0; index < asset.reviews.length; index++) {
				RWToken.transfer(asset.reviews[index].reviewer, asset_review_fee);
			}
		}

		emit AssetReviewed(rating, metadata, msg.sender, community, review_metadata);
		return rating;
	}
}
