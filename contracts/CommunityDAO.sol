// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@opengsn/contracts/src/ERC2771Recipient.sol";

contract CommunityDAO is ERC2771Recipient{

  address payable _owner;
  uint256 public _total_members;
  address public trustedForwarder;
  address public _verified_contract;

  mapping(address => bool) public _members;
  mapping(string => Proposal) public _proposals;
  mapping(address => uint256) public _credibility;

  event ProposalSubmit(string, address);
  event ProposalAccepted(string, address);
  event ProposalDeclined(string, address);

  struct Proposal {
    bool _isActive;
    string _metadata;
    uint256 _upvotes;
    uint256 _downvotes;
    address payable _proposed_member;
    mapping(address => bool) _member_voted;
  }

  constructor(address _trustedForwarder) {
    _owner = payable(msg.sender);
    trustedForwarder = _trustedForwarder;
    _members[payable(msg.sender)] = true;
    _total_members += 1;
  }

  modifier _onlyOwner {
    require(_msgSender() == _owner, "Sender is not owner of smart contract.");
    _;
  }

  modifier _onlyMember {
    require(_members[_msgSender()], "Sender is not a member of the community.");
    _;
  }

  modifier _onlyVerified {
    require(_msgSender() == _verified_contract, "Only verified contract can perform this action.");
    _;
  }

  function setTrustedForwarder(address _trustedForwarder) public _onlyOwner {
    trustedForwarder = _trustedForwarder;
  }

  function setCredibility(address _member, uint256 _credit) public _onlyVerified {
    _credibility[_member] += _credit;
  }

  function createProposal(string memory _metadata, address payable _member) public _onlyMember {
    _proposals[_metadata]._upvotes = 1;
    _proposals[_metadata]._isActive = true;
    _proposals[_metadata]._metadata = _metadata;
    _proposals[_metadata]._proposed_member = _member;
    vote(_metadata, true);
    emit ProposalSubmit(_metadata, _msgSender());
  }

  function vote(string memory _metadata, bool _upvote) public _onlyMember {
    Proposal storage _proposal = _proposals[_metadata];
    require(_proposal._isActive, "Proposal has been marked as completed.");
    require(!_proposal._member_voted[_msgSender()], "Community member has already voted on this proposal.");
    if (_upvote) _proposal._upvotes++;
    else _proposal._downvotes++;
    if (_proposal._upvotes >= _total_members / 2) {
      _members[_proposal._proposed_member] = true;
      _total_members++;
      _proposal._isActive = false;
      emit ProposalAccepted(_metadata, _proposal._proposed_member);
    }
    if (_proposal._downvotes > _total_members / 2) {
      _proposal._isActive = false;
      emit ProposalDeclined(_metadata, _proposal._proposed_member);
    }
    _proposal._member_voted[_msgSender()] = true;
  }
}
