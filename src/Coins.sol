// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

error OnlyNative();
error OnlyExternal();
error Unauthorized();
error AlreadyCreated();
error InvalidMetadata();

/// @title Coins
/// @notice Singleton for tokens
/// @author z0r0z & 0xc0de4c0ffee
contract Coins {
    event MetadataSet(uint256 indexed);
    event ERC20Created(uint256 indexed);
    event OwnershipTransferred(uint256 indexed);

    event OperatorSet(address indexed, address indexed, bool);
    event Approval(address indexed, address indexed, uint256 indexed, uint256);
    event Transfer(address, address indexed, address indexed, uint256 indexed, uint256);

    mapping(uint256 id => Metadata) internal _metadata;

    mapping(uint256 id => uint256) public totalSupply;
    mapping(uint256 id => address owner) public ownerOf;

    mapping(address owner => mapping(uint256 id => uint256)) public balanceOf;
    mapping(address owner => mapping(address operator => bool)) public isOperator;
    mapping(address owner => mapping(address spender => mapping(uint256 id => uint256))) public
        allowance;

    modifier onlyOwnerOf(uint256 id) {
        require(msg.sender == ownerOf[id], Unauthorized());
        _;
    }

    constructor() payable {}

    // COIN METADATA

    struct Metadata {
        string name;
        string symbol;
        string tokenURI;
        bool native;
    }

    function name(uint256 id) public view returns (string memory) {
        return _metadata[id].native ? _metadata[id].name : Token(address(uint160(id))).name();
    }

    function symbol(uint256 id) public view returns (string memory) {
        return _metadata[id].native ? _metadata[id].symbol : Token(address(uint160(id))).symbol();
    }

    function decimals(uint256 id) public view returns (uint8) {
        return _metadata[id].native ? 18 : Token(address(uint160(id))).decimals();
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
        require(bytes(_symbol).length != 0, InvalidMetadata()); // Must have coin ticker.
        uint256 id = uint160(_predictAddress(keccak256(abi.encodePacked(_name, _symbol))));
        require(!_metadata[id].native, AlreadyCreated()); // Must be unique coin creation.
        _metadata[id] = Metadata(_name, _symbol, _tokenURI, true); // Name and symbol set.
        _mint(ownerOf[id] = owner, id, supply); // Mint initial supply to the owner.
    }

    // CREATE2 ERC20 TOKENS

    function createToken(uint256 id) public {
        require(_metadata[id].native, OnlyNative());
        new Token{salt: keccak256(abi.encodePacked(_metadata[id].name, _metadata[id].symbol))}();
        emit ERC20Created(id);
    }

    function tokenize(uint256 id, uint256 amount) public {
        require(_metadata[id].native, OnlyNative());
        _burn(msg.sender, id, amount);
        Token(address(uint160(id))).mint(msg.sender, amount);
    }

    function untokenize(uint256 id, uint256 amount) public {
        require(_metadata[id].native, OnlyNative());
        Token(address(uint160(id))).burn(msg.sender, amount);
        _mint(msg.sender, id, amount);
    }

    function _predictAddress(bytes32 salt) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xFF), address(this), salt, keccak256(type(Token).creationCode)
                        )
                    )
                )
            )
        );
    }

    // COIN ID MINT/BURN

    function mint(address to, uint256 id, uint256 amount) public onlyOwnerOf(id) {
        _mint(to, id, amount);
    }

    function burn(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
    }

    // COIN ID GOVERNANCE

    function setMetadata(uint256 id, string calldata _tokenURI) public onlyOwnerOf(id) {
        _metadata[id].tokenURI = _tokenURI;
        emit MetadataSet(id);
    }

    function transferOwnership(uint256 id, address newOwner) public onlyOwnerOf(id) {
        ownerOf[id] = newOwner;
        emit OwnershipTransferred(id);
    }

    // COIN ID WRAPPING

    function wrap(Token token, uint256 amount) public {
        uint256 id = uint256(uint160(address(token)));
        require(!_metadata[id].native, OnlyExternal());
        token.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, id, amount);
    }

    function unwrap(Token token, uint256 amount) public {
        uint256 id = uint256(uint160(address(token)));
        require(!_metadata[id].native, OnlyExternal());
        _burn(msg.sender, id, amount);
        token.transfer(msg.sender, amount);
    }

    // ERC6909

    function transfer(address to, uint256 id, uint256 amount) public returns (bool) {
        balanceOf[msg.sender][id] -= amount;
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
            if (allowed != type(uint256).max) {
                allowance[from][msg.sender][id] = allowed - amount;
            }
        }
        balanceOf[from][id] -= amount;
        unchecked {
            balanceOf[to][id] += amount;
        }
        emit Transfer(msg.sender, from, to, id, amount);
        return true;
    }

    function approve(address spender, uint256 id, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    function setOperator(address operator, bool approved) public returns (bool) {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    // ERC165

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0x0f632fb3; // ERC6909
    }

    // INTERNAL MINT/BURN

    function _mint(address to, uint256 id, uint256 amount) internal {
        totalSupply[id] += amount;
        unchecked {
            balanceOf[to][id] += amount;
        }
        emit Transfer(msg.sender, address(0), to, id, amount);
    }

    function _burn(address from, uint256 id, uint256 amount) internal {
        balanceOf[from][id] -= amount;
        unchecked {
            totalSupply[id] -= amount;
        }
        emit Transfer(msg.sender, from, address(0), id, amount);
    }
}

contract Token {
    event Approval(address indexed, address indexed, uint256);
    event Transfer(address indexed, address indexed, uint256);

    uint8 public constant decimals = 18;

    uint256 public totalSupply;

    address internal immutable COINS = msg.sender;

    mapping(address owner => uint256) public balanceOf;
    mapping(address owner => mapping(address spender => uint256)) public allowance;

    constructor() payable {}

    function name() public view returns (string memory) {
        return Coins(COINS).name(uint160(address(this)));
    }

    function symbol() public view returns (string memory) {
        return Coins(COINS).symbol(uint160(address(this)));
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) 
            allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public payable {
        require(msg.sender == COINS, Unauthorized());
        unchecked {
            totalSupply += amount;
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) public payable {
        require(msg.sender == COINS, Unauthorized());
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
