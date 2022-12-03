// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./lib/GenesisUtils.sol";
import "./verifiers/ZKPVerifier.sol";

contract CommunityDAO is ZKPVerifier, AccessControl {
  	using Timers for Timers.BlockNumber;

	uint256 public quorum;
	uint256 public _total_members;
	uint256 public _voting_period;

    uint64 public constant MEMBERSHIP_REQUEST_ID = 1;

	mapping(address => uint64) public last_block_request;
	mapping(uint256 => address) public idToAddress;
    mapping(address => uint256) public addressToId;

	mapping(address => uint256) public credibility;
	mapping(address => Proposal) public membership_proposals;

	enum ProposalType {
		ADD_MEMBER,
		REMOVE_MEMBER,
		CHANGE_MIN_VOTES
	}

	event MembershipProposalCreate(address proposer, address new_member, uint64 voteStart,
	 uint64 voteEnd, string descriptionHash);

	event QuorumUpdated(uint256 quorum);
	event MemberAdded(address member, address community);
	event MembershipCriteriaUpdated(uint256 min_degree, uint256[] institutes);

	event Voted(address member, bool support, string descriptionHash);
	event CredibilityUpdated(address member, int256 credibility);

	struct Proposal {
		Timers.BlockNumber voteStart;
		Timers.BlockNumber voteEnd;
		bool executed;
		bool canceled;
		uint256 votes;
		string descriptionHash;
		mapping(address => bool) members_voted;
	}

	struct MembershipCriteria {
		uint8 degree;
		uint256[] institutions;
		mapping(uint256 => bool) allowed_institutions;
	}

	MembershipCriteria public criteria;

	enum ProposalState {
		Pending,
		Active,
		Canceled,
		Defeated,
		Succeeded,
		Queued,
		Expired,
		Executed
	}

	bytes32 public constant MEMBER_ROLE = keccak256("MEMBER_ROLE");
	bytes32 public constant VERIFIED_CONTRACT_ROLE = keccak256("VERIFIED_CONTRACT_ROLE");

	constructor(address _verified_contract) {
		quorum = 1;
		_total_members += 1;
		_voting_period = 10000;
		_grantRole(MEMBER_ROLE, _msgSender());
		_grantRole(VERIFIED_CONTRACT_ROLE, _verified_contract);
	}

	modifier onlyMember {
		require(hasRole(MEMBER_ROLE, _msgSender()), "Signer: sender is not a member of the community.");
		_;
	}

	modifier onlyVerified {
		require(hasRole(VERIFIED_CONTRACT_ROLE, _msgSender()), "Signer: only verified contract can perform this action.");
		_;
	}

	function setCredibility(address _member, uint256 _credit, bool increase) public onlyVerified {
		int256 member_credibility = int256(credibility[_member]);
		if (increase) {
			member_credibility += int256(_credit);
		} else {
			if (int256(_credit) > member_credibility) member_credibility = 1;
			else member_credibility -= int256(_credit);
		}
		credibility[_member] = uint256(member_credibility);
		emit CredibilityUpdated(_member, member_credibility);
	}

	function addVerifiedContract(address _verified_contract) public onlyOwner {
		_grantRole(VERIFIED_CONTRACT_ROLE, _verified_contract);
	}

	function removeVerifiedContract(address _verified_contract) public onlyOwner {
		_revokeRole(VERIFIED_CONTRACT_ROLE, _verified_contract);
	}

	function quorumReached(Proposal storage proposal) internal view returns(bool) {
		return proposal.voteEnd.getDeadline() >= block.number;
	}

	function voteSucceeded(Proposal storage proposal) internal view returns(bool) {
		return quorumReached(proposal) && proposal.votes >= quorum;
	}

	function isMember(address _member) public view returns(bool) {
		return hasRole(MEMBER_ROLE, _member);
	}

	function hashProposal(
		uint256 value,
		bytes memory _calldata,
		bytes32 descriptionHash
	) internal view returns (uint256) {
		return uint256(keccak256(abi.encode(address(this), value, _calldata, descriptionHash)));
	}

	function state(Proposal storage proposal) internal view returns (ProposalState) {
		if (proposal.executed) return ProposalState.Executed;
		if (proposal.canceled) return ProposalState.Canceled;

		uint256 snapshot = proposal.voteStart.getDeadline();

		if (snapshot == 0) revert("Governor: unknown proposal id");
		if (snapshot >= block.number) return ProposalState.Pending;

		uint256 deadline = proposal.voteEnd.getDeadline();

		if (deadline >= block.number) return ProposalState.Active;

		if (quorumReached(proposal) && voteSucceeded(proposal)) return ProposalState.Succeeded;
		else return ProposalState.Defeated;
	}

	function addMember(address member) internal {
		require(!hasRole(MEMBER_ROLE, member), "Account: already a member.");
		_grantRole(MEMBER_ROLE, member);
		_total_members++;
		credibility[member] = 1;
	}

	function setQuorum(uint256 _quorum) public onlyOwner {
		require(_quorum >= 1, "Invalid Argument: _quorum should be greater than or equal to 1");
		quorum = _quorum;
		emit QuorumUpdated(_quorum);
	}

	function setMembershipCriteria(uint8 _degree, uint256[] memory _allowed_institutions) public onlyOwner {
		criteria.degree = _degree;
		for (uint256 index = 0; index < criteria.institutions.length; index++) {
			criteria.allowed_institutions[criteria.institutions[index]] = false;
		}
		for (uint256 index = 0; index < _allowed_institutions.length; index++) {
			criteria.allowed_institutions[_allowed_institutions[index]] = true;	
		}
		emit MembershipCriteriaUpdated(_degree, _allowed_institutions);
	}

	function _beforeProofSubmit(
        uint64, /* requestId */
        uint256[] memory inputs,
        ICircuitValidator validator
    ) internal view override {
        // check that challenge input of the proof is equal to the msg.sender 
        address addr = GenesisUtils.int256ToAddress(
            inputs[validator.getChallengeInputIndex()]
        );
        require(
            _msgSender() == addr,
            "address in proof is not a sender address"
        );
    }

    function _afterProofSubmit(
        uint64 requestId,
        uint256[] memory inputs,
        ICircuitValidator validator
    ) internal override {
        require(
            requestId == MEMBERSHIP_REQUEST_ID && block.number - last_block_request[_msgSender()] > 10000,
            "need to wait 10000 blocks before applying again"
        );
		require(!hasRole(MEMBER_ROLE, _msgSender()), "is already a member");

        uint256 id = inputs[validator.getChallengeInputIndex()];
        if (idToAddress[id] == address(0)) {
            addressToId[_msgSender()] = id;
            idToAddress[id] = _msgSender();
			_proposeMembership(_msgSender(), "Membership Proposal via Polygon ID");
        }
    }

	function _beforeProposeMembership(address _new_member) internal view {
		require(proofs[_new_member][MEMBERSHIP_REQUEST_ID], "only identities who provided proof are allowed to join");
	}

	function _proposeMembership(address _new_member, string memory descriptionHash) internal {

		_beforeProposeMembership(_new_member);
		
		Proposal storage proposal = membership_proposals[_new_member];

		proposal.descriptionHash = descriptionHash;

		require(proposal.voteStart.isUnset(), "Governor: proposal already exists");

		uint64 snapshot = uint64(block.number);
		uint64 deadline = snapshot + uint64(_voting_period);

		proposal.voteStart.setDeadline(snapshot);
		proposal.voteEnd.setDeadline(deadline);

		emit MembershipProposalCreate(
			_msgSender(),
			_new_member,
			proposal.voteStart.getDeadline(),
			proposal.voteEnd.getDeadline(),
			proposal.descriptionHash
		);
	}

	function castVoteMembership(address _new_member, bool support) public onlyMember {
		Proposal storage proposal = membership_proposals[_new_member];
		require(state(proposal) == ProposalState.Active, "Governor: vote not currently active");

		if(support) proposal.votes += 1;
		proposal.members_voted[_msgSender()] = true;

		emit Voted(_msgSender(), support, proposal.descriptionHash);

		if (voteSucceeded(proposal)) addMember(_new_member);
	}
}
