// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Test {
    bytes32[] y;
    bytes32 g;

    constructor () {
        y.push(keccak256(abi.encodePacked(msg.sender)));
        g = y[0];
    }

    function getY() view public returns(bytes32[] memory) {
        return y;
    }
    
    function getG() view public returns(bytes32) {
        return g;
    }

    function changeY() public {
        bytes32 u;
        g = u;
        bytes32[] memory e;
        y = e;
    }

    function hashAddress(address a) public pure returns(bytes32){
        return keccak256(abi.encodePacked(a));
    }
    function hashString(string memory s) public pure returns(bytes32){
        return keccak256(abi.encodePacked(s));
    }
}