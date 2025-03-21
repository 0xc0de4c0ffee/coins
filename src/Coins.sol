// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

error Unauthorized();
error AlreadyCreated();
error InvalidMetadata();

contract Coins {
    event MetadataSet(uint256 indexed);
    event ERC20Created(uint256 indexed);
    event OwnershipTransferred(uint256 indexed);

    event OperatorSet(address indexed, address indexed, bool);
    event Approval(address indexed, address indexed, uint256 indexed, uint256);
    event Transfer(address, address indexed, address indexed, uint256 indexed, uint256);

    mapping(uint256 id => Metadata) internal _metadata;
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

    // CREATE2 ERC20 TOKENS

    function createToken(uint256 id) public {
        require(bytes(_metadata[id].symbol).length != 0, Unauthorized());
        new Token{salt: bytes32(id)}(id);
        emit ERC20Created(id);
    }

    function tokenize(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
        Token(_predictAddress(id)).mint(msg.sender, amount);
    }

    function untokenize(uint256 id, uint256 amount) public {
        Token(_predictAddress(id)).burn(msg.sender, amount);
        _mint(msg.sender, id, amount);
    }

    function _predictAddress(uint256 id) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xFF),
                            address(this),
                            bytes32(id),
                            keccak256(abi.encodePacked(type(Token).creationCode, abi.encode(id)))
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

    function wrap(address token, uint256 amount) public {
        _mint(msg.sender, uint256(uint160(token)), amount);
        Token(token).transferFrom(msg.sender, address(this), amount);
    }

    function unwrap(address token, uint256 amount) public {
        _burn(msg.sender, uint256(uint160(token)), amount);
        Token(token).transfer(msg.sender, amount);
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
            if (allowed != type(uint256).max) allowance[from][msg.sender][id] = allowed - amount;
        }
        balanceOf[from][id] -= amount;
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
    event Approval(address indexed from, address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    string public name;
    string public symbol;
    uint256 public constant decimals = 18;

    uint256 public totalSupply;

    address internal immutable COINS = msg.sender;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(uint256 id) payable {
        (name, symbol) = (Coins(msg.sender).name(id), Coins(msg.sender).symbol(id));
    }

    function approve(address to, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][to] = amount;
        emit Approval(msg.sender, to, amount);
        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public payable virtual {
        require(msg.sender == COINS, Unauthorized());
        unchecked {
            totalSupply += amount;
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) public payable virtual {
        require(msg.sender == COINS, Unauthorized());
        balanceOf[from] -= amount;
        unchecked {
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
