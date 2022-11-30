// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract ReviewerToken is ERC20Permit {
    constructor(uint256 _amount) ERC20("ReviewerToken", "RWT") ERC20Permit("ReviewerToken") {
        _mint(_msgSender(), _amount * 10 ** decimals());
    }
} 