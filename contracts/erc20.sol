// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Heircules is ERC20, Ownable {
    uint constant decimal = 18;
    
    constructor()
        ERC20("Heircules", "HCLS")
        Ownable(msg.sender)
    {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount * (10 ** decimal));
    }
}