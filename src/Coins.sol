// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

error OnlyExternal();
error Unauthorized();
error InvalidMetadata();
error DeploymentFailed();

/// @title Coins
/// @notice Singleton for ERC6909 & ERC20s
/// @author z0r0z & 0xc0de4c0ffee & kobuta23
contract Coins {
    event MetadataSet(uint256 indexed);
    event OwnershipTransferred(uint256 indexed);

    event OperatorSet(address indexed, address indexed, bool);
    event Approval(address indexed, address indexed, uint256 indexed, uint256);
    event Transfer(address, address indexed, address indexed, uint256 indexed, uint256);

    Token immutable implementation = new Token{salt: keccak256("")}();

    mapping(uint256 id => Metadata) _metadata;

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

    // METADATA

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

    // CREATION

    function create(
        string calldata _name,
        string calldata _symbol,
        string calldata _tokenURI,
        address owner,
        uint256 supply
    ) public {
        require(bytes(_tokenURI).length != 0, InvalidMetadata());
        uint256 id;
        Token _implementation = implementation;
        bytes32 salt = keccak256(abi.encode(_name, _symbol));
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
        _metadata[id] = Metadata(_name, _symbol, _tokenURI);
        emit Transfer(
            msg.sender,
            address(0),
            ownerOf[id] = owner,
            id,
            balanceOf[owner][id] = totalSupply[id] = supply
        );
    }

    // WRAPPING

    function wrap(Token token, uint256 amount) public {
        uint256 id = uint160(address(token));
        require(bytes(_metadata[id].tokenURI).length == 0, OnlyExternal());
        token.transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, id, amount);
    }

    function unwrap(Token token, uint256 amount) public {
        _burn(msg.sender, uint256(uint160(address(token))), amount);
        token.transfer(msg.sender, amount);
    }

    // MINT/BURN

    function mint(address to, uint256 id, uint256 amount) public onlyOwnerOf(id) {
        _mint(to, id, amount);
    }

    function burn(uint256 id, uint256 amount) public {
        _burn(msg.sender, id, amount);
    }

    // GOVERNANCE

    function setMetadata(uint256 id, string calldata _tokenURI) public onlyOwnerOf(id) {
        require(bytes(_tokenURI).length != 0, InvalidMetadata());
        _metadata[id].tokenURI = _tokenURI;
        emit MetadataSet(id);
    }

    function transferOwnership(uint256 id, address newOwner) public onlyOwnerOf(id) {
        ownerOf[id] = newOwner;
        emit OwnershipTransferred(id);
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
        if (msg.sender != address(uint160(id))) {
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

    // ERC20 APPROVAL

    function setAllowance(address owner, address spender, uint256 id, uint256 amount)
        public
        payable
        returns (bool)
    {
        require(msg.sender == address(uint160(id)), Unauthorized());
        allowance[owner][spender][id] = amount;
        emit Approval(owner, spender, id, amount);
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

    uint256 public constant decimals = 18;
    address immutable coins = msg.sender;

    constructor() payable {}

    function name() public view returns (string memory) {
        return Coins(coins).name(uint160(address(this)));
    }

    function symbol() public view returns (string memory) {
        return Coins(coins).symbol(uint160(address(this)));
    }

    function totalSupply() public view returns (uint256) {
        return Coins(coins).totalSupply(uint160(address(this)));
    }

    function balanceOf(address owner) public view returns (uint256) {
        return Coins(coins).balanceOf(owner, uint160(address(this)));
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        if (Coins(coins).isOperator(owner, spender)) return type(uint256).max;
        return Coins(coins).allowance(owner, spender, uint160(address(this)));
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        emit Approval(msg.sender, spender, amount);
        return Coins(coins).setAllowance(msg.sender, spender, uint160(address(this)), amount);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        emit Transfer(msg.sender, to, amount);
        return Coins(coins).transferFrom(msg.sender, to, uint160(address(this)), amount);
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(
            Coins(coins).allowance(from, msg.sender, uint160(address(this))) >= amount,
            Unauthorized()
        );
        emit Transfer(from, to, amount);
        return Coins(coins).transferFrom(from, to, uint160(address(this)), amount);
    }
}
