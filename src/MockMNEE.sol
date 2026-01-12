// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockMNEE is ERC20, Ownable, ERC20Permit {
    uint256 public constant MINT_AMOUNT = 100000 * 10 ** 18;

    constructor(
        address recipient,
        address initialOwner
    ) ERC20("MNEE", "MNEE") Ownable(initialOwner) ERC20Permit("MNEE") {
        _mint(recipient, 2000000 * 10 ** decimals());
    }

    function mint(address to) public {
        _mint(to, MINT_AMOUNT);
    }
}
