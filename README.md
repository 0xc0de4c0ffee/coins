# [Coins](https://github.com/z0r0z/coins)  
[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](https://opensource.org/license/mit/) 
[![solidity](https://img.shields.io/badge/solidity-%5E0.8.29-black)](https://docs.soliditylang.org/en/v0.8.25/) 
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000.svg)](https://getfoundry.sh/) 
![tests](https://github.com/z0r0z/coins/actions/workflows/ci.yml/badge.svg)  

Hyper-minimal fungible token singleton built on ERC6909 with two-way compatibility with ERC20.  

![diagram](diagram.png)  

## Overview

Coins is a singleton smart contract for creating and managing fungible tokens using the ERC6909 multi-token standard. It provides a gas-efficient alternative to deploying multiple ERC20 token contracts while maintaining compatibility with the ERC20 standard.

## Features

- **Singleton Architecture**: Create multiple token types within a single contract
- **ERC6909 Implementation**: Implements the modern multi-token standard
- **ERC20 Compatibility**: Two-way conversion between Coins tokens and ERC20 tokens
- **Metadata Support**: Name, symbol, and URI storage for each token ID
- **Token Wrapping**: Wrap existing ERC20 tokens to use within the Coins ecosystem
- **Ownership & Permissions**: Flexible permission system with ownership and operators

## Core Functionality

### Token Creation

```solidity
function create(
    string calldata _name,
    string calldata _symbol,
    string calldata _tokenURI,
    address owner,
    uint256 supply
) public
```

Creates a new token ID with associated metadata, owner, and initial supply.

### ERC20 Compatibility

```solidity
function createToken(uint256 id) public
```

Deploys an ERC20-compatible token contract for an existing token ID.

```solidity
function tokenize(uint256 id, uint256 amount) public
function untokenize(uint256 id, uint256 amount) public
```

Convert between native Coins tokens and ERC20 tokens.

### Token Wrapping

```solidity
function wrap(Token token, uint256 amount) public
function unwrap(Token token, uint256 amount) public
```

Wrap existing ERC20 tokens for use within Coins, and unwrap them to retrieve the original ERC20 tokens.

### Token Management

```solidity
function mint(address to, uint256 id, uint256 amount) public
function burn(uint256 id, uint256 amount) public
```

Mint new tokens (restricted to token owner) and burn your own tokens.

### Governance

```solidity
function setMetadata(uint256 id, string calldata _tokenURI) public
function transferOwnership(uint256 id, address newOwner) public
```

Update token metadata and transfer token ownership (restricted to token owner).

### Standard ERC6909 Functions

```solidity
function transfer(address to, uint256 id, uint256 amount) public
function transferFrom(address from, address to, uint256 id, uint256 amount) public
function approve(address spender, uint256 id, uint256 amount) public
function setOperator(address operator, bool approved) public
```

Standard token operations for transfers, approvals, and operator settings.

## Token Contract

The `Token` contract is automatically created when using `createToken()` and provides standard ERC20 functionality:

- `name()` and `symbol()`: Inherited from Coins metadata
- `approve()`, `transfer()`, `transferFrom()`: Standard ERC20 functions
- `mint()` and `burn()`: Restricted to the Coins contract

## Getting Started  

Run: `curl -L https://foundry.paradigm.xyz | bash && source ~/.bashrc && foundryup`  

Build the foundry project with `forge build`. Run tests with `forge test`. Measure gas with `forge snapshot`. Format with `forge fmt`.  

## GitHub Actions  

Contracts will be tested and gas measured on every push and pull request.  

## Blueprint  

```txt
lib 
├─ forge-std — https://github.com/foundry-rs/forge-std 
├─ solady — https://github.com/vectorized/solady 
src 
├─ Coins — Coins Contract 
test 
└─ Coins.t - Coins Test Contract 
```  

## Disclaimer  

*These smart contracts and testing suite are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of anything provided herein or through related user interfaces. This repository and related code have not been audited and as such there can be no assurance anything will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk.*  

## License  

See [LICENSE](./LICENSE) for more details.