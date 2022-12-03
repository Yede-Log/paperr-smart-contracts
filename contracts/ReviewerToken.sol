// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

import "./lib/GenesisUtils.sol";
import "./verifiers/ZKPVerifier.sol";

contract ReviewerToken is ERC20Permit, ZKPVerifier {
    
    mapping(uint256 => address) public idToAddress;
    mapping(address => uint256) public addressToId;

    uint64 public constant TRANSFER_REQUEST_ID = 1;
    uint256 public AGE_VERIFICATION_REWARD;

    constructor(uint256 _amount, uint64 _verification_reward) ERC20("ReviewerToken", "RWT") ERC20Permit("ReviewerToken") {
        proofs[_msgSender()][TRANSFER_REQUEST_ID] = true;
        _mint(_msgSender(), _amount * 10 ** decimals());
        AGE_VERIFICATION_REWARD = _verification_reward * 10 ** decimals(); 
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
            requestId == TRANSFER_REQUEST_ID && addressToId[_msgSender()] == 0,
            "proof can not be submitted more than once"
        );

        uint256 id = inputs[validator.getChallengeInputIndex()];
        if (idToAddress[id] == address(0)) {
            _mint(_msgSender(), AGE_VERIFICATION_REWARD);
            addressToId[_msgSender()] = id;
            idToAddress[id] = _msgSender();
        }
    }

    function _beforeTokenTransfer(
        address,
        address to,
        uint256
    ) internal view override {
        require(
            proofs[to][TRANSFER_REQUEST_ID] == true,
            "only identities who provided proof are allowed to receive tokens"
        );
    }
}