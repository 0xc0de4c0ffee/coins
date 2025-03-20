// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

contract Coins {
    event MetadataSet(uint256 indexed);
    event OwnershipTransferred(uint256 indexed);

    event OperatorSet(address indexed, address indexed, bool);
    event Approval(address indexed, address indexed, uint256 indexed, uint256);
    event Transfer(address, address indexed, address indexed, uint256 indexed, uint256);

    error Unauthorized();
    error AlreadyCreated();
    error InvalidMetadata();

    mapping(uint256 id => Metadata) public _metadata;
    mapping(uint256 id => address owner) public ownerOf;
    mapping(uint256 id => uint256) public totalSupply;

    mapping(address => mapping(address => bool)) public isOperator;
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;

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

    function name(uint256 id) public view returns (string memory) {
        return _metadata[id].name;
    }

    function symbol(uint256 id) public view returns (string memory) {
        return _metadata[id].symbol;
    }

    function decimals(uint256) public pure returns (uint8) {
        return 18;
    }

    function tokenURI(uint256 id) public view returns (string memory) {
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

        _mint(ownerOf[id] = owner, id, supply);
    }

    // COIN ID MINT/BURN

    function mint(address to, uint256 id, uint256 amount) public onlyOwnerOf(id) {
        _mint(to, id, amount);
    }

    function burn(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
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
        _mint(msg.sender, uint256(uint160(asset)), amount);
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function unwrap(address asset, uint256 amount) public {
        _burn(msg.sender, uint256(uint160(asset)), amount);
        IERC20(asset).transfer(msg.sender, amount);
    }

    // ERC6909

    function transfer(address to, uint256 id, uint256 amount) public returns (bool) {
        balanceOf[msg.sender][id] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit Transfer(msg.sender, msg.sender, to, id, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 id, uint256 amount)
        public
        returns (bool)
    {
        if (msg.sender != from && !isOperator[from][msg.sender]) {
            uint256 allowed = allowance[from][msg.sender][id];
            if (allowed != type(uint256).max) allowance[from][msg.sender][id] = allowed - amount;
        }

        balanceOf[from][id] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit Transfer(msg.sender, from, to, id, amount);

        return true;
    }

    function approve(address to, uint256 id, uint256 amount) public returns (bool) {
        allowance[msg.sender][to][id] = amount;
        emit Approval(msg.sender, to, id, amount);
        return true;
    }

    function setOperator(address operator, bool approved) public returns (bool) {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    // ERC165

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165.
            || interfaceId == 0x0f632fb3; // ERC165 Interface ID for ERC6909.
    }

    // INTERNAL MINT/BURN

    function _mint(address to, uint256 id, uint256 amount) internal {
        totalSupply[id] += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit Transfer(msg.sender, address(0), to, id, amount);
    }

    function _burn(address from, uint256 id, uint256 amount) internal {
        balanceOf[from][id] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply[id] -= amount;
        }

        emit Transfer(msg.sender, from, address(0), id, amount);
    }
}

interface IERC20 {
    function transfer(address, uint256) external;
    function transferFrom(address, address, uint256) external;
}
