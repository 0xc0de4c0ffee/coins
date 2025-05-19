// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./Coins.sol";
/// @title Coins
/// @notice Singleton for ERC6909 & ERC20s
/// @author z0r0z & 0xc0de4c0ffee & kobuta23

contract ManyCoins is Coins {
    constructor() {}

    // METADATA

    struct ManyData {
        Token[] tokens;
        uint256[] amounts;
    }

    mapping(uint256 id => ManyData) _manyData;
    //mapping(Token token => uint256) public totalWrapped;
    //mapping(uint256 id => mapping(Token token => uint256 amount)) public wrapped;
    // CREATION

    error TokenNotSorted();
    error InsufficientBalance();

    function reindex(
        address recipient,
        uint256 supply,
        string calldata _name,
        string calldata _symbol,
        string calldata _tokenURI,
        Token[] calldata tokens,
        uint256[] calldata amounts
    ) external {
        require(bytes(_tokenURI).length != 0, InvalidMetadata());
        require(tokens.length == amounts.length, InvalidMetadata());
        uint256 id;
        Token _implementation = implementation;
        bytes32 salt = keccak256(abi.encodePacked(_name, address(this), _symbol, block.chainid));
        unchecked {
            assembly ("memory-safe") {
                mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
                mstore(0x14, _implementation)
                mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)
                id := create2(0, 0x0c, 0x35, salt)
                if iszero(id) {
                    mstore(0x00, 0x30116425) // `DeploymentFailed()`
                    revert(0x1c, 0x04)
                }
                mstore(0x21, 0)
            }
        }
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            tokens[i].transferFrom(msg.sender, address(this), (amounts[i] * supply) / 1e18);
        }
        _metadata[id] = Metadata(_name, _symbol, _tokenURI);
        _manyData[id] = ManyData(tokens, amounts);
        emit Transfer(
            msg.sender,
            address(0),
            recipient,
            id,
            balanceOf[recipient][id] = totalSupply[id] = supply
        );
    }

    // WRAPPING
    error OnlyManyCoins();

    function wrapMany(uint256 id, uint256 amount) public {
        Token[] memory tokens = _manyData[id].tokens;
        require(tokens.length > 0, OnlyManyCoins());
        uint256[] memory amounts = _manyData[id].amounts;
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            tokens[i].transferFrom(msg.sender, address(this), (amount * amounts[i]) / 1e18);
        }
        totalSupply[id] += amount;
        unchecked {
            balanceOf[msg.sender][id] += amount;
        }
        emit Transfer(msg.sender, address(0), msg.sender, id, amount);
    }

    function unwrapMany(uint256 id, uint256 amount) public {
        require(balanceOf[msg.sender][id] >= amount, InsufficientBalance());
        require(_manyData[id].tokens.length > 0, OnlyManyCoins());
        unchecked {
            totalSupply[id] -= amount;
            balanceOf[msg.sender][id] -= amount;
        }
        Token[] memory tokens = _manyData[id].tokens;
        uint256[] memory amounts = _manyData[id].amounts;
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            tokens[i].transfer(msg.sender, (amount * amounts[i]) / 1e18);
        }
        emit Transfer(msg.sender, msg.sender, address(0), id, amount);
    }
}
