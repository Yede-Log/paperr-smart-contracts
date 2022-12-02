// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Timers.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract CommunityDAO is Ownable, AccessControl {
	address public EPNS_CORE_ADDRESS =0x97D7c5f14B8fe94Ef2b4bA589379f5Ec992197dA;
    address public EPNS_COMM_ADDRESS=0x87da9Af1899ad477C67FeA31ce89c1d2435c77DC;
	address  payable public owner;

  	using Timers for Timers.BlockNumber;

	uint256 public quorum;
	uint256 public _total_members;
	uint256 public _voting_period;

	mapping(uint256 => Proposal) private proposals;
	mapping(address => uint256) public credibility;

	enum ProposalType {
		ADD_MEMBER,
		REMOVE_MEMBER,
		CHANGE_MIN_VOTES
	}

	event ProposalCreated(
		uint256 proposalId,
		address proposer,
		address target,
		uint256 value,
		bytes32 signatures,
		bytes _calldata,
		uint256 startBlock,
		uint256 endBlock,
		string description
	);

	struct Proposal {
		Timers.BlockNumber voteStart;
		Timers.BlockNumber voteEnd;
		bool executed;
		bool canceled;
		uint256 votes;
		address target;
		uint256 value;
		bytes _calldata;
		bytes32 descriptionHash;
		mapping(address => bool) members_voted;
	}

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
		owner = payable(msg.sender);
	}

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform the task");
        _;
    }
	modifier onlyMember {
		require(hasRole(MEMBER_ROLE, _msgSender()), "Signer: sender is not a member of the community.");
		_;
	}

	modifier onlyVerified {
		require(hasRole(VERIFIED_CONTRACT_ROLE, _msgSender()), "Signer: only verified contract can perform this action.");
		_;
	}

	modifier onlyGovernance {
		require(_msgSender() == address(this), "Governor: action requires voting from DAO members.");
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
	}

	function quorumReached(Proposal storage proposal) internal view returns(bool) {
		return proposal.voteEnd.getDeadline() >= block.number;
	}

	function voteSucceeded(Proposal storage proposal) internal view returns(bool) {
		return quorumReached(proposal) && proposal.votes >= quorum;
	}

	function isMember(address payable _member) public view returns(bool) {
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

	function addMember(address payable member) public onlyGovernance {
		require(!hasRole(MEMBER_ROLE, member), "Account: already a member.");
		_grantRole(MEMBER_ROLE, member);
		_total_members++;
		credibility[member] = 1;
		_sendNotification(msg.sender, member);
	}

	function removeMember(address payable member) public onlyGovernance {
		require(hasRole(MEMBER_ROLE, member), "Account: not a member.");
		_revokeRole(MEMBER_ROLE, member);
		_total_members--;
		credibility[member] = 0;
	}

	function setQuorum(uint256 _quorum) public onlyGovernance {
		require(_quorum >= 1, "Invalid Argument: _quorum should be greater than or equal to 1");
		quorum = _quorum;
	}

	function setVotingPeriod(uint256 _voting_period_) public onlyGovernance {
		require(_voting_period_ >= 10000, "Invalid Argument: _voting_period_ should be greater than or equal to 10000");
		_voting_period = _voting_period_;
	}

	function propose(
		uint256 value,
		bytes memory _calldata,
		string memory description
	) public onlyMember returns(uint256) {

		uint256 proposalId = hashProposal(value, _calldata, keccak256(bytes(description)));

		Proposal storage proposal = proposals[proposalId];
		require(proposal.voteStart.isUnset(), "Governor: proposal already exists");

		uint64 snapshot = uint64(block.number);
		uint64 deadline = snapshot + uint64(_voting_period);

		proposal.voteStart.setDeadline(snapshot);
		proposal.voteEnd.setDeadline(deadline);

		emit ProposalCreated(
			proposalId,
			_msgSender(),
			address(this),
			value,
			keccak256(_msgData()),
			_calldata,
			snapshot,
			deadline,
			description
		);
        _sendNotification(_msgSender(), _msgSender());
		return proposalId;
	}

	function castVote(uint256 proposalId, bool support) public onlyMember {
		Proposal storage proposal = proposals[proposalId];
		require(state(proposal) == ProposalState.Active, "Governor: vote not currently active");

		if(support) proposal.votes += 1;
		proposal.members_voted[_msgSender()] = true;

		if (voteSucceeded(proposal)) execute(proposal);
	}

	function execute(Proposal storage proposal) internal {
		string memory errorMessage = "Governor: call reverted without message";
		(bool success, bytes memory returndata) = address(this).call{value: proposal.value}(proposal._calldata);
		Address.verifyCallResult(success, returndata, errorMessage);
	}

	function createChannelWithEPNS(string memory _ipfsHash) public onlyOwner {
        IEPNSCoreInterface(EPNS_CORE_ADDRESS).createChannelWithFees(
            IEPNSCoreInterface.ChannelType.InterestBearingOpen,
            bytes(string(
            abi.encodePacked(
                "2",
                "+",
                _ipfsHash
            )
        )),
            50 ether
        );
    }

	function _sendNotification(address _sender, address _receiver) {
		IEPNSCommInterface(EPNS_COMM_ADDRESS).sendNotification(_sender, _receiver, bytes(string(
            abi.encodePacked(
                "1",
                "+",
                "QmSyKMiRvpQpiaUyXR3BmCXjSme6xFNxypD5Jn8GTBAELM"
            )
        )));
	}
}
