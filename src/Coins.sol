// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {ERC6909} from "@solady/src/tokens/ERC6909.sol";

contract Coins is ERC6909 {
    event MetadataSet(uint256 indexed id);
    event OwnershipTransferred(uint256 indexed id);

    error Unauthorized();
    error AlreadyCreated();
    error InvalidMetadata();

    mapping(uint256 id => Metadata) public _metadata;

    mapping(uint256 id => address owner) public ownerOf;

    mapping(uint256 id => uint256) public totalSupply;

    modifier onlyOwnerOf(uint256 id) {
        require(msg.sender == ownerOf[id], Unauthorized());
        _;
    }

    // COIN METADATA

    struct Metadata {
        string name;
        string symbol;
        string tokenURI;
    }

    function name(uint256 id) public view override(ERC6909) returns (string memory) {
        return _metadata[id].name;
    }

    function symbol(uint256 id) public view override(ERC6909) returns (string memory) {
        return _metadata[id].symbol;
    }

    function decimals(uint256) public pure override(ERC6909) returns (uint8) {
        return 18;
    }

    function tokenURI(uint256 id) public view override(ERC6909) returns (string memory) {
        return _metadata[id].tokenURI;
    }

    // COIN ID CREATION

    function create(
        string calldata _name,
        string calldata _symbol,
        string calldata _tokenURI,
        address owner,
        uint256 supply
    ) public {
        require(bytes(_symbol).length != 0, InvalidMetadata()); // Must have ticker.

        uint256 id = uint256(keccak256(abi.encodePacked(_name, _symbol, _tokenURI)));

        require(bytes(_metadata[id].symbol).length == 0, AlreadyCreated()); // New.

        _metadata[id] = Metadata(_name, _symbol, _tokenURI);

        _mint(ownerOf[id] = owner, id, totalSupply[id] = supply);
    }

    // COIN ID MINT/BURN

    function mint(address to, uint256 id, uint256 amount) public onlyOwnerOf(id) {
        totalSupply[id] += amount;
        _mint(to, id, amount);
    }

    function burn(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
        unchecked {
            totalSupply[id] -= amount;
        }
    }

    // COIN ID GOVERNANCE

    function setMetadata(
        uint256 id,
        string calldata _name,
        string calldata _symbol,
        string calldata _tokenURI
    ) public onlyOwnerOf(id) {
        _metadata[id] = Metadata(_name, _symbol, _tokenURI);
        emit MetadataSet(id);
    }

    function transferOwnership(uint256 id, address newOwner) public onlyOwnerOf(id) {
        ownerOf[id] = newOwner;
        emit OwnershipTransferred(id);
    }

    // COIN ID WRAPPING

    function wrap(address asset, uint256 amount) public {
        totalSupply[uint256(uint160(asset))] += amount;
        _mint(msg.sender, uint256(uint160(asset)), amount);
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function unwrap(address asset, uint256 amount) public {
        _burn(msg.sender, uint256(uint160(asset)), amount);
        unchecked {
            totalSupply[uint256(uint160(asset))] -= amount;
        }
        IERC20(asset).transfer(msg.sender, amount);
    }
}

interface IERC20 {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}
