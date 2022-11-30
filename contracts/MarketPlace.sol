// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ReviewerToken.sol";
import "./ReviewedAssetNFT.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RANMarketPlace is Ownable {
    using Timers for Timers.BlockNumber;

	address public erc20_token;
	address public erc721_token;

    enum ListingState {
        ACTIVE,
        COMPLETED,
        EXPIRED
    }

    struct Listing {
        uint256 basePrice;
        ListingState state;
        address payable owner;
        mapping(address => Bid) bids;
        Timers.BlockNumber biddingStart;
        Timers.BlockNumber biddingEnd;
    }

    mapping(address => mapping(uint256 => Listing)) listings;

    struct Bid {
        uint256 amount;
        uint8 asset_rating;
        bool active;
        Timers.BlockNumber start;
        Timers.BlockNumber end;
    }

    constructor(address _erc20_tokenAddress, address _erc721_tokenAddress) {
		erc20_token = _erc20_tokenAddress;
		erc721_token = _erc721_tokenAddress;
    }

    function createListing(uint256 _tokenId, uint256 _basePrice, uint64 period) public {
        Listing storage listing = listings[_msgSender()][_tokenId];
        listing.basePrice = _basePrice;
        listing.owner = payable(_msgSender());
        listing.biddingStart.setDeadline(uint64(block.number));
        listing.biddingEnd.setDeadline(uint64(block.number + period));
        listing.state = ListingState.ACTIVE;
    }

    function bid(
        address payable _owner,
        uint256 _tokenId, uint256 _amount,
        uint64 bidPeriod, uint8 _rating,
		uint8 v, bytes32 r, bytes32 s
    ) public {
        Listing storage listing = listings[_owner][_tokenId];
        listing.bids[_msgSender()].active = true;    
        listing.bids[_msgSender()].amount = _amount;
        listing.bids[_msgSender()].asset_rating = _rating;
        listing.bids[_msgSender()].start.setDeadline(uint64(block.number));
        listing.bids[_msgSender()].end.setDeadline(uint64(block.number + bidPeriod));
		ReviewerToken RWToken = ReviewerToken(erc20_token);
        RWToken.permit(_msgSender(), address(this), _amount, block.number + bidPeriod, v, r, s);
    }

    function withdrawBid() public {

    }

    function acceptBid() public {

    }

}
