// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "./Coins.sol";

contract Token {
    event Approval(address indexed from, address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    function totalSupply() public view returns (uint256) {
        return Coins(COINS).totalSupply(uint256(uint160(address(this))));
    }

    address internal immutable COINS = msg.sender;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) payable {
        (name, symbol) = (_name, _symbol);
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
        //unchecked {
            balanceOf[to] += amount;
        //}
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) public payable virtual {
        require(msg.sender == COINS, Unauthorized());
        balanceOf[from] -= amount;
        emit Transfer(from, address(0), amount);
    }
    
}