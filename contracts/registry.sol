// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "contracts/proxy.sol";

contract Registry {
    address operator;

    mapping(address => mapping(address => bool)) walletMap;
    mapping(address => address[]) walletMapArr;
    mapping(address => uint256) walletCount;
    mapping(address => uint256) registryCount;
    mapping(address => address) walletMapRev;

    constructor() {
        operator = msg.sender;
    }

    modifier onlyOperator() {
        require(operator == msg.sender);
        _;
    }

    function deployWallet() public {
        Proxy wallet;
        if (registryCount[msg.sender] == 0) {
            uint salt = 10;
            wallet = new Proxy{salt: bytes32(salt)}(
                msg.sender,
                address(this)
            );
        } else {
            wallet = new Proxy(msg.sender, address(this));
        }
        walletMap[msg.sender][address(wallet)] = true;
        walletMapArr[msg.sender].push(address(wallet));
        walletCount[msg.sender]++;
        registryCount[msg.sender]++;
        walletMapRev[address(wallet)] = msg.sender;
    }

    function updateWallet(address _newOwner) public {
        address a = Proxy(payable(msg.sender)).getOperator();
        require(a == _newOwner, "can not update registry");

        address prevOwner = walletMapRev[msg.sender];
        walletMapRev[msg.sender] = _newOwner;
        walletMap[prevOwner][msg.sender] = false;
        walletMap[_newOwner][msg.sender] = true;
        walletMapArr[_newOwner].push(msg.sender);
        walletCount[prevOwner]--;
        walletCount[_newOwner]++;
        registryCount[_newOwner]++;
    }

    function getWallets(address _operator)
        public
        view
        returns (address[] memory)
    {
        uint256 j = 0;

        for (uint256 i = 0; i < walletMapArr[_operator].length; i++) {
            address a = walletMapArr[_operator][i];
            if (walletMap[_operator][a] == true) {
                j++;
            }
        }
        
        address[] memory wallets = new address[](j);
        uint x = 0;

        for (uint256 i = 0; i < walletMapArr[_operator].length; i++) {
            address a = walletMapArr[_operator][i];
            if (walletMap[_operator][a] == true) {
                wallets[x] = a;
                x++;
            }
        }

        return wallets;
    }

    function getOperator(address _wallet) public view returns (address) {
        return walletMapRev[_wallet];
    }


    function getAddress(address _owner)
        public
        view
        returns (address)
    {
        uint salt = 10;
        bytes memory bytecode_ = type(Proxy).creationCode;
        bytes memory bytecode = abi.encodePacked(bytecode_, abi.encode(_owner, address(this)));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff), address(this), salt, keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }
}
