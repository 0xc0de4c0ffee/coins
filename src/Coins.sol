// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./Token.sol";

error Unauthorized();
error AlreadyCreated();
error InvalidMetadata();
error NotMintable();

contract Coins {
    event MetadataSet(uint256 indexed);
    event ERC20Created(address indexed, string indexed, string indexed);
    event OwnershipTransferred(uint256 indexed);

    event OperatorSet(address indexed, address indexed, bool);
    event Approval(address indexed, address indexed, uint256 indexed, uint256);
    event Transfer(address, address indexed, address indexed, uint256 indexed, uint256);

    mapping(uint256 id => string uri) public tokenURI;
    mapping(uint256 id => bool mint) public mintable;
    mapping(uint256 id => address owner) public ownerOf;
    // keep total supply
    mapping(uint256 id => uint256) internal _totalSupply;
    // track all wrapped/tokenized tokens
    mapping(uint256 id => uint256) public tokenized;
    mapping(address => mapping(address => bool)) public isOperator;
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public allowance;

    modifier onlyOwnerOf(uint256 id) {
        require(msg.sender == ownerOf[id], Unauthorized());
        _;
    }

    constructor() {

    }

    // COIN METADATA

    function name(uint256 id) public view returns (string memory _name) {
        return Token(address(uint160(id))).name();
    }

    function symbol(uint256 id) public view returns (string memory _symbol) {
        return Token(address(uint160(id))).symbol();
    }

    function decimals(uint256 id) public view returns (uint8) {
        return Token(address(uint160(id))).decimals();
    }

    function totalSupply(uint256 id) public view returns (uint256) {
        if(bytes(tokenURI[id]).length == 0){
            return Token(address(uint160(id))).totalSupply();
        }
        return _totalSupply[id];
    }

    // COIN ID CREATION

    function createToken(
        string calldata _name,
        string calldata _symbol,
        string calldata _tokenURI,
        address owner,
        uint256 supply,
        bool _mintable
    ) public {
        require(bytes(_tokenURI).length > 0, InvalidMetadata());
        require(bytes(_name).length != 0, InvalidMetadata());
        require(bytes(_symbol).length != 0, InvalidMetadata());
        address _token = _predictAddress(_name, _symbol);
        uint256 id = uint256(uint160(_token));
        new Token{salt: bytes32(id)}(_name, _symbol);
        emit ERC20Created(_token, _name, _symbol);
        tokenURI[id] = _tokenURI;
        mintable[id] = _mintable;
        _totalSupply[id] = supply;
        balanceOf[owner][id] = supply;
        emit Transfer(address(0), address(0), owner, id, supply);
    }

    function _predictAddress(string calldata _name, string calldata _symbol)
        internal
        view
        returns (address)
    {
        uint256 salt = uint256(keccak256(abi.encodePacked(_name, _symbol, address(this))));
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xFF),
                            address(this),
                            bytes32(salt),
                            keccak256(abi.encodePacked(type(Token).creationCode, abi.encode(_name, _symbol)))
                        )
                    )
                )
            )
        );
    }

    // COIN ID MINT/BURN

    function mint(address to, uint256 id, uint256 amount) public onlyOwnerOf(id) {
        require(mintable[id], NotMintable());
        _totalSupply[id] += amount;
        unchecked {
            balanceOf[to][id] += amount;
        }
        emit Transfer(msg.sender, address(0), to, id, amount);
    }

    function burn(uint256 id, uint256 amount) public {
        balanceOf[msg.sender][id] -= amount;
        unchecked {
            _totalSupply[id] -= amount;
        }
        emit Transfer(msg.sender, msg.sender, address(0), id, amount);
    }

    // COIN ID GOVERNANCE

    function setMetadata(uint256 id, string calldata _tokenURI) public onlyOwnerOf(id) {
        require(bytes(_tokenURI).length > 0, InvalidMetadata());
        tokenURI[id] = _tokenURI;
        emit MetadataSet(id);
    }

    function transferOwnership(uint256 id, address newOwner) public onlyOwnerOf(id) {
        ownerOf[id] = newOwner;
        emit OwnershipTransferred(id);
    }

    // TOKENIZE / UNTOKENIZE
    function tokenize(uint256 id, uint256 amount) public {
        require(bytes(tokenURI[id]).length > 0, Unauthorized());
        balanceOf[msg.sender][id] -= amount;
        unchecked {
            tokenized[id] += amount;
        }
        Token(address(uint160(id))).mint(msg.sender, amount);
        emit Transfer(msg.sender, msg.sender, address(0), id, amount);
    }

    function untokenize(uint256 id, uint256 amount) public {
        require(bytes(tokenURI[id]).length > 0, Unauthorized());
        Token(address(uint160(id))).burn(msg.sender, amount);
        unchecked {
            balanceOf[msg.sender][id] += amount;
            tokenized[id] -= amount;
        }
        emit Transfer(msg.sender, address(0), msg.sender, id, amount);
    }

    // WRAP / UNWRAP
    function wrap(address token, uint256 amount) public {
        uint256 id = uint256(uint160(token));
        require(bytes(tokenURI[id]).length == 0, Unauthorized());
        Token(token).transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender][id] += amount; // don't trust external tokens
        unchecked {
            tokenized[id] += amount;
        }
        emit Transfer(msg.sender, address(0), msg.sender, id, amount);
    }

    function unwrap(address token, uint256 amount) public {
        uint256 id = uint256(uint160(token));
        require(bytes(tokenURI[id]).length == 0, Unauthorized());
        balanceOf[msg.sender][id] -= amount;
        unchecked {
            tokenized[id] -= amount;
        }
        emit Transfer(msg.sender, msg.sender, address(0), id, amount);
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
}

