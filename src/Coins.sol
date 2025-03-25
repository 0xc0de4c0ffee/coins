// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

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
    }

    function name(uint256 id) public view returns (string memory) {
        Metadata storage meta = _metadata[id];
        return bytes(meta.tokenURI).length != 0 ? meta.name : Token(address(uint160(id))).name();
    }

    function symbol(uint256 id) public view returns (string memory) {
        Metadata storage meta = _metadata[id];
        return bytes(meta.tokenURI).length != 0 ? meta.symbol : Token(address(uint160(id))).symbol();
    }

    function decimals(uint256 id) public view returns (uint8) {
        return bytes(_metadata[id].tokenURI).length != 0
            ? 18
            : uint8(Token(address(uint160(id))).decimals());
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
        require(bytes(_tokenURI).length != 0, InvalidMetadata());
        uint256 id = uint160(
            uint256(
                keccak256(
                    abi.encodePacked(
                        bytes1(0xFF),
                        this,
                        keccak256(abi.encodePacked(_name, _symbol)),
                        keccak256(type(Token).creationCode)
                    )
                )
            )
        );
        require(bytes(_metadata[id].tokenURI).length == 0, AlreadyCreated());
        _metadata[id] = Metadata(_name, _symbol, _tokenURI);
        emit Transfer(
            msg.sender,
            address(0),
            ownerOf[id] = owner,
            id,
            balanceOf[owner][id] = totalSupply[id] = supply
        );
    }

    // CREATE2 ERC20 TOKENS

    function createToken(uint256 id) public {
        Metadata storage meta = _metadata[id];
        require(bytes(meta.tokenURI).length != 0, InvalidMetadata());
        new Token{salt: keccak256(abi.encodePacked(meta.name, meta.symbol))}();
        emit ERC20Created(id);
    }

    function tokenize(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
        Token(address(uint160(id))).mint(msg.sender, amount);
    }

    function untokenize(uint256 id, uint256 amount) public {
        Token(address(uint160(id))).burn(msg.sender, amount);
        _mint(msg.sender, id, amount);
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
        require(bytes(_tokenURI).length != 0, InvalidMetadata());
        _metadata[id].tokenURI = _tokenURI;
        emit MetadataSet(id);
    }

    function transferOwnership(uint256 id, address newOwner) public onlyOwnerOf(id) {
        ownerOf[id] = newOwner;
        emit OwnershipTransferred(id);
    }

    // COIN ID WRAPPING

    function wrap(Token token, uint256 amount) public {
        token.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, uint256(uint160(address(token))), amount);
    }

    function unwrap(Token token, uint256 amount) public {
        _burn(msg.sender, uint256(uint160(address(token))), amount);
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
        if (msg.sender != from) {
            if (!isOperator[from][msg.sender]) {
                if (allowance[from][msg.sender][id] != type(uint256).max) {
                    allowance[from][msg.sender][id] -= amount;
                }
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

    uint256 public totalSupply;

    uint256 public constant decimals = 18;
    address internal immutable coins = msg.sender;

    mapping(address owner => uint256) public balanceOf;
    mapping(address owner => mapping(address spender => uint256)) public allowance;

    constructor() payable {}

    function name() public view returns (string memory) {
        return Coins(coins).name(uint160(address(this)));
    }

    function symbol() public view returns (string memory) {
        return Coins(coins).symbol(uint160(address(this)));
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
        if (allowance[from][msg.sender] != type(uint256).max) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public payable {
        require(msg.sender == coins, Unauthorized());
        unchecked {
            totalSupply += amount;
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) public payable {
        require(msg.sender == coins, Unauthorized());
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
