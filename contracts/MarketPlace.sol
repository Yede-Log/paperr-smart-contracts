// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ReviewerToken.sol";
import "./ReviewedAssetNFT.sol";
import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract RANMarketPlace is Ownable {
    using Timers for Timers.BlockNumber;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

	address public erc20_token;
	address public erc721_token;
    address public reviewer_contract;

    enum ListingState {
        ACTIVE,
        COMPLETED,
        EXPIRED
    }

    struct Listing {
        uint256 basePrice;
        ListingState state;
        address payable owner;
        Timers.BlockNumber biddingStart;
        Timers.BlockNumber biddingEnd;
        EnumerableMap.AddressToUintMap bidRatings;
        EnumerableMap.AddressToUintMap bidAmounts;
    }

    mapping(address => mapping(uint256 => Listing)) listings;

    constructor(address _erc20_tokenAddress, address _erc721_tokenAddress) {
		erc20_token = _erc20_tokenAddress;
		erc721_token = _erc721_tokenAddress;
    }

    function setReviewerContract(address _reviewer_contract) public onlyOwner{
        reviewer_contract = _reviewer_contract;
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
        uint8 _rating, uint8 v, bytes32 r, bytes32 s
    ) public {
        Listing storage listing = listings[_owner][_tokenId];
        EnumerableMap.set(listing.bidAmounts, _msgSender(), _amount);
        EnumerableMap.set(listing.bidRatings, _msgSender(), _rating);
		ReviewerToken RWToken = ReviewerToken(erc20_token);
        RWToken.permit(_msgSender(), address(this), _amount, listing.biddingEnd.getDeadline(), v, r, s);
    }

    function withdrawBid(
        uint256 _tokenId, address _owner
    ) public {
        Listing storage listing = listings[_owner][_tokenId];
        EnumerableMap.remove(listing.bidAmounts, _msgSender());
        EnumerableMap.remove(listing.bidRatings, _msgSender());
    }

    function acceptBid(uint256 _tokenId, address _bidder) public {
        Listing storage listing = listings[_msgSender()][_tokenId];
        ReviewerToken RWToken = ReviewerToken(erc20_token);
        ReviewedAssetNFT RANToken = ReviewedAssetNFT(erc721_token);
        RANToken.tokenURI(_tokenId);
        RANToken.transferFrom(_msgSender(), _bidder, _tokenId);
        RWToken.transferFrom(_bidder, _msgSender(), EnumerableMap.get(listing.bidAmounts, _bidder));
        for (uint256 index = 0; index < EnumerableMap.length(listings[_msgSender()][_tokenId].bidAmounts); index++) {
            (address key, ) = EnumerableMap.at(listing.bidAmounts, index);
            EnumerableMap.remove(listing.bidAmounts, key);
        }
        delete listings[_msgSender()][_tokenId];
    }

}
