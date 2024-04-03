// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "contracts/registry.sol";

struct Recovery {
    bytes32[] canRecover;
    bytes32 passcodeHash;
    uint256 window;
    uint256 pingedAt;
    bool initialized;
}

contract Proxy {
    uint256 nonce;
    address operator;
    address registry;
    Recovery private recovery;

    constructor(address _operator, address _registry) {
        registry = _registry;
        operator = _operator;
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "Only operator can call this function");
        _;
    }

    modifier ping() {
        _;
        recovery.pingedAt = block.timestamp;
    }

    function transferERC20(
        address token,
        address to,
        uint256 amount
    ) public onlyOperator ping {
        (bool success, ) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success, "unsuccessful");
    }

    function transferERC721(
        address token,
        address to,
        uint256 id
    ) public onlyOperator ping {
        (bool success, ) = token.call(
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                address(this),
                to,
                id
            )
        );
        require(success, "unsuccessful");
    }

    function transferERC1155(
        address token,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public onlyOperator ping {
        (bool success, ) = token.call(
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,uint256,bytes)",
                address(this),
                to,
                id,
                amount,
                data
            )
        );

        require(success, "unsuccessful");
    }

    function transferNative(address to, uint256 amount)
        public
        onlyOperator
        ping
    {
        bool success = payable(to).send(amount);
        require(success, "unsuccessful");
    }

    function handleTransaction() public payable ping onlyOperator {
        //===================================================================
        // the proposed schemas as shown below  after function (4 bytes)
        // slot --> content
        // 1    --> 20bytes for the contract address, 1 bytes for the calls, 5 bytes for the calldata lengths
        // 2 to (2 + sum of call sizes)   --> calldata
        // (2 + sum of call sizes) + (1 * num of calls) --> call values respectively
        // (2 + sum of call sizes) + (1 * num of calls) + 1 --> extimated gas fees (7 bytes for each. a zero byte would mean gas() be used)
        //===================================================================

        assembly {
            //amounts of bytes sofar inspected on the calldata from the function signature to the passphrases
            let sofar := 4

            //contract address (20 bytes) + bundle size (1 byte) max is 5 calls + data size for each calldata (1 byte each) max is 5 bytes == 26 bytes
            let header := calldataload(sofar)
            sofar := add(sofar, 32)

            //getting the contract address
            let a := and(header, 0xffffffffffffffffffffffffffffffffffffffff)

            //getting the number of calls - 1 byte
            let bs := and(shr(160, header), 0xff)
            // let bs := and(header, 0xff0000000000000000000000000000000000000000)

            //getting the calldata sizes in the bundle - 5 bytes
            let cds := shr(168, header)
            // let cds := and(header, 0xffffffffff000000000000000000000000000000000000000000)

            //get bundle calldata area
            let bca := add(
                add(
                    add(and(shr(32, cds), 0xff), and(shr(24, cds), 0xff)),
                    add(and(shr(16, cds), 0xff), and(shr(8, cds), 0xff))
                ),
                and(shr(0, cds), 0xff)
            )

            // //get gas fees from the last 32 byte slot on the calldata. 4 bytes each for each txn
            let gfs := calldataload(add(add(sofar, bca), mul(32, bs)))

            //loop through the bundle and make the calls
            let y := sofar

            function _getgas(egf) -> g {
                if iszero(egf) {
                    g := gas()
                    leave
                }

                g := egf
            }

            for {
                let i := 0
            } lt(i, bs) {
                i := add(i, 0x01)
            } {
                // getting the callvalue for the transaction
                mstore(0, calldataload(add(add(y, bca), mul(i, 0x20))))
                //0000000000000000000000000000ffffffffffffffffffffffffffffffffffff
                //0000000000000000000000000000ffff0000ffff0000ffff0000ffff0000ffff
                let gf := and(shr(mul(i, 32), gfs), 0xffffffff)
                let size := and(shr(mul(i, 8), cds), 0xff)
                calldatacopy(mload(0x40), sofar, size)

                let success := call(
                    _getgas(gf),
                    a,
                    mload(0),
                    mload(0x40),
                    size,
                    0,
                    0
                )
                returndatacopy(mload(0x40), 0, returndatasize())
                if iszero(success) {
                    revert(mload(0x40), returndatasize())
                }

                sofar := add(sofar, size)
            }
        }

        nonce++;
    }

    
    /*
        Recovery
    */

    function recoverAccount(string calldata _passcode, address _newAccount) public {
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        bool canSend = false;
        for (uint256 i = 0; i < recovery.canRecover.length; i++) {
            if (sender == recovery.canRecover[i]) {
                canSend = true;
                break;
            }
        }
        require(canSend, "You cannot recover this account");

        bytes32 recoveryHash = keccak256(abi.encodePacked(_passcode));

        require(recoveryHash == recovery.passcodeHash, "wrong passcode");

        bytes32 j;
        bytes32[] memory y;

        operator = _newAccount;
        recovery.canRecover = y;
        recovery.passcodeHash = j;
        recovery.initialized = false;
        recovery.window = 0;
        recovery.pingedAt = block.timestamp;
        updateRegistry(_newAccount);
    }

    function addRecovery(
        bytes32[] calldata _canRecover,
        bytes32 _passcodeHash,
        uint256 window
    ) public onlyOperator {
        require(
            !recovery.initialized && msg.sender == operator,
            "already initialized"
        );

        recovery.canRecover = _canRecover;
        recovery.passcodeHash = _passcodeHash;
        recovery.initialized = true;
        recovery.window = 1 minutes * window;
        recovery.pingedAt = block.timestamp;
    }

    function kinRecovery() public {
        bytes32 sender = keccak256(abi.encodePacked(msg.sender));
        bool canSend = false;
        uint256 index = 0;
        for (uint256 i = 0; i < recovery.canRecover.length; i++) {
            if (sender == recovery.canRecover[i]) {
                canSend = true;
                index = i;
                break;
            }
        }
        require(canSend, "You cannot recover this account");
        require(
            (recovery.window + recovery.pingedAt) +
                ((index * recovery.window) / 10) <
                block.timestamp,
            "access denied"
        );

        bytes32 j;
        bytes32[] memory y;

        recovery.canRecover = y;
        recovery.passcodeHash = j;
        recovery.initialized = false;
        recovery.window = 0;
        recovery.pingedAt = block.timestamp;
        operator = msg.sender;
        updateRegistry(msg.sender);
    }

    function updateRegistry(address _newOwner) private {
        Registry(registry).updateWallet(_newOwner);
    }

    function pingWallet() public onlyOperator ping {}

    /*
        All functions below are getters
    */

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getNonce() public view returns (uint256) {
        return nonce;
    }

    function getAddress() public view returns (address) {
        return address(this);
    }

    function getOperator() public view returns (address) {
        return operator;
    }

    function getRecoveryInfo() public view returns(Recovery memory) {
        return recovery;
    }

    /*
        NFT compliance
    */

    function onERC721Received(
        address a,
        address b,
        uint256 c,
        bytes calldata d
    ) public pure returns (bytes4) {
        a;
        b;
        c;
        d;
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function onERC1155BatchReceived(
        address _operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external pure returns (bytes4) {
        _operator;
        from;
        ids;
        values;
        data;
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }

    function onERC1155BatchReceived(
        address _operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes4) {
        _operator;
        from;
        id;
        value;
        data;
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    fallback() external payable {}

    receive() external payable {}
}

//A function that returns the wallet balance;
//An allow maplist for feature layering
