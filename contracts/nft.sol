// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Heircules is ERC721, Ownable {
    uint256 public nonce;

    constructor()
        ERC721("Heircules", "HCLS")
        Ownable(msg.sender)
    {

    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://bafybeibhecnykgrppt3f6rh6a6vphyn3pzyqzxzceyto623bfxv4srdsda/";
    }

    function safeMint() public payable {
        require(msg.value >= 10, "Not enough funds");
        uint256 tokenId = ++nonce;
        _safeMint(msg.sender, tokenId);
    }

    function getNonce() public view returns(uint256) {
        return nonce;
    }
}
