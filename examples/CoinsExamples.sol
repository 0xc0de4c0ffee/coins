// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "../src/Coins.sol";

/**
 * @title CoinsExamples
 * @notice Example contract demonstrating how to use the Coins contract
 */
contract CoinsExamples {
    Coins public coins;
    
    constructor(Coins _coins) {
        coins = _coins;
    }
    
    /**
     * @notice Example 1: Creating a new token with the Coins contract
     * @param name Token name
     * @param symbol Token symbol
     * @param tokenURI Metadata URI for the token
     * @param initialSupply Initial token supply (with 18 decimals)
     * @return id The newly created token ID
     */
    function example1_CreateToken(
        string calldata name,
        string calldata symbol,
        string calldata tokenURI,
        uint256 initialSupply
    ) external returns (uint256 id) {
        // Create the token with specified parameters
        coins.create(
            name,               // Token name
            symbol,             // Token symbol
            tokenURI,           // Metadata URI
            msg.sender,         // Owner (the caller)
            initialSupply       // Initial supply (with 18 decimals)
        );
        
        // Calculate the deterministic token ID
        id = uint160(
            uint256(
                keccak256(
                    abi.encodePacked(
                        bytes1(0xFF),
                        address(coins),
                        keccak256(abi.encodePacked(name, symbol)),
                        keccak256(type(Token).creationCode)
                    )
                )
            )
        );
        
        return id;
    }
    
    /**
     * @notice Example 2: Getting token metadata and information
     * @param id Token ID to query
     * @return tokenName The token name
     * @return tokenSymbol The token symbol
     * @return tokenDecimals The token decimals
     * @return tokenURI The token URI
     * @return supply The total supply
     * @return owner The token owner
     */
    function example2_GetTokenInfo(uint256 id) external view returns (
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        string memory tokenURI,
        uint256 supply,
        address owner
    ) {
        tokenName = coins.name(id);
        tokenSymbol = coins.symbol(id);
        tokenDecimals = coins.decimals(id);
        tokenURI = coins.tokenURI(id);
        supply = coins.totalSupply(id);
        owner = coins.ownerOf(id);
        
        return (tokenName, tokenSymbol, tokenDecimals, tokenURI, supply, owner);
    }
    
    /**
     * @notice Example 3: ERC20 Compatibility - Creating an ERC20 token from a Coins token ID
     * @param id Token ID to convert to ERC20
     * @return tokenAddress The address of the created ERC20 token
     */
    function example3_CreateERC20Token(uint256 id) external returns (address tokenAddress) {
        // Create the ERC20 token contract
        coins.createToken(id);
        
        // The token address is deterministically generated from the ID
        tokenAddress = address(uint160(id));
        
        return tokenAddress;
    }
    
    /**
     * @notice Example 4: Converting between Coins tokens and ERC20 tokens
     * @param id Token ID to convert
     * @param amount Amount to convert (with 18 decimals)
     */
    function example4_TokenizeAndUntokenize(uint256 id, uint256 amount) external {
        // First, convert from Coins tokens to ERC20 tokens
        coins.tokenize(id, amount);
        
        // Now, convert back from ERC20 tokens to Coins tokens
        coins.untokenize(id, amount);
    }
    
    /**
     * @notice Example 5: Wrapping an existing ERC20 token
     * @param existingToken Address of the existing ERC20 token
     * @param amount Amount to wrap (with token decimals)
     */
    function example5_WrapExistingToken(address existingToken, uint256 amount) external {
        Token token = Token(existingToken);
        
        // First, approve the Coins contract to take your tokens
        token.approve(address(coins), amount);
        
        // Wrap the tokens
        coins.wrap(token, amount);
        
        // The token ID for the wrapped token is the token's address
        uint256 wrappedTokenId = uint256(uint160(existingToken));
        
        // Check the balance
        uint256 balance = coins.balanceOf(msg.sender, wrappedTokenId);
        require(balance >= amount, "Wrapping failed");
    }
    
    /**
     * @notice Example 6: Unwrapping back to the original ERC20 token
     * @param existingToken Address of the existing ERC20 token
     * @param amount Amount to unwrap (with token decimals)
     */
    function example6_UnwrapToken(address existingToken, uint256 amount) external {
        // Unwrap the tokens to get the original ERC20 tokens back
        coins.unwrap(Token(existingToken), amount);
        
        // Verify the balance of the original token increased
        uint256 originalBalance = Token(existingToken).balanceOf(msg.sender);
        require(originalBalance >= amount, "Unwrapping failed");
    }
    
    /**
     * @notice Example 7: Basic token transfer operations
     * @param id Token ID to transfer
     * @param recipient Recipient address
     * @param amount Amount to transfer (with 18 decimals)
     */
    function example7_TransferTokens(uint256 id, address recipient, uint256 amount) external {
        // Simple transfer from caller to recipient
        coins.transfer(recipient, id, amount);
        
        // Check recipient's balance
        uint256 recipientBalance = coins.balanceOf(recipient, id);
        require(recipientBalance >= amount, "Transfer failed");
    }
    
    /**
     * @notice Example 8: Approvals and transferFrom
     * @param id Token ID to approve
     * @param spender Address to approve
     * @param amount Amount to approve (with 18 decimals)
     */
    function example8_ApproveAndTransfer(uint256 id, address spender, address recipient, uint256 amount) external {
        // First, approve the spender
        coins.approve(spender, id, amount);
        
        // Check the allowance
        uint256 allowanceAmount = coins.allowance(msg.sender, spender, id);
        require(allowanceAmount >= amount, "Approval failed");
        
        // Now, as the spender, transfer from the approver to a recipient
        // This would typically be called by the spender, not the approver
        coins.transferFrom(msg.sender, recipient, id, amount);
    }
    
    /**
     * @notice Example 9: Setting and using operators
     * @param operator Address to set as an operator
     */
    function example9_SetOperatorAndTransfer(uint256 id, address operator, address recipient, uint256 amount) external {
        // Set an address as an operator (can transfer any token you own)
        coins.setOperator(operator, true);
        
        // Check if the operator setting was successful
        bool isOp = coins.isOperator(msg.sender, operator);
        require(isOp, "Operator setting failed");
        
        // Now, as the operator, transfer any token from the approver to a recipient
        // This would typically be called by the operator, not the token owner
        coins.transferFrom(msg.sender, recipient, id, amount);
    }
    
    /**
     * @notice Example 10: Minting new tokens (only token owner can do this)
     * @param id Token ID to mint
     * @param recipient Recipient of the new tokens
     * @param amount Amount to mint (with 18 decimals)
     */
    function example10_MintTokens(uint256 id, address recipient, uint256 amount) external {
        // Only the token owner can mint new tokens
        // This will fail if msg.sender is not the token owner
        coins.mint(recipient, id, amount);
        
        // Check the recipient's balance and total supply
        uint256 recipientBalance = coins.balanceOf(recipient, id);
        uint256 newTotalSupply = coins.totalSupply(id);
        
        require(recipientBalance >= amount, "Minting failed");
        require(newTotalSupply >= amount, "Total supply update failed");
    }
    
    /**
     * @notice Example 11: Burning tokens
     * @param id Token ID to burn
     * @param amount Amount to burn (with 18 decimals)
     */
    function example11_BurnTokens(uint256 id, uint256 amount) external {
        // Get the initial balance and total supply
        uint256 initialBalance = coins.balanceOf(msg.sender, id);
        uint256 initialSupply = coins.totalSupply(id);
        
        // Burn tokens
        coins.burn(id, amount);
        
        // Verify balance and total supply decreased
        uint256 newBalance = coins.balanceOf(msg.sender, id);
        uint256 newSupply = coins.totalSupply(id);
        
        require(newBalance == initialBalance - amount, "Burning failed");
        require(newSupply == initialSupply - amount, "Total supply update failed");
    }
    
    /**
     * @notice Example 12: Updating token metadata (only token owner can do this)
     * @param id Token ID to update
     * @param newTokenURI New token URI to set
     */
    function example12_UpdateMetadata(uint256 id, string calldata newTokenURI) external {
        // Only the token owner can update metadata
        // This will fail if msg.sender is not the token owner
        coins.setMetadata(id, newTokenURI);
        
        // Verify the URI was updated
        string memory updatedURI = coins.tokenURI(id);
        
        // Compare strings - note this is a simplistic comparison
        bytes32 newURIHash = keccak256(abi.encodePacked(newTokenURI));
        bytes32 updatedURIHash = keccak256(abi.encodePacked(updatedURI));
        
        require(newURIHash == updatedURIHash, "Metadata update failed");
    }
    
    /**
     * @notice Example 13: Transferring token ownership (only token owner can do this)
     * @param id Token ID to transfer ownership
     * @param newOwner New owner address
     */
    function example13_TransferOwnership(uint256 id, address newOwner) external {
        // Only the token owner can transfer ownership
        // This will fail if msg.sender is not the token owner
        coins.transferOwnership(id, newOwner);
        
        // Verify ownership was transferred
        address updatedOwner = coins.ownerOf(id);
        require(updatedOwner == newOwner, "Ownership transfer failed");
    }
    
    /**
     * @notice Example 14: Full token lifecycle - create, modify, transfer, and burn
     * @param name Token name
     * @param symbol Token symbol
     * @param tokenURI Token URI
     * @param initialSupply Initial supply
     * @param recipient Recipient for some tokens
     */
    function example14_FullTokenLifecycle(
        string calldata name,
        string calldata symbol,
        string calldata tokenURI,
        uint256 initialSupply,
        address recipient
    ) external {
        // 1. Create the token
        coins.create(name, symbol, tokenURI, msg.sender, initialSupply);
        
        // Calculate the token ID
        uint256 id = uint160(
            uint256(
                keccak256(
                    abi.encodePacked(
                        bytes1(0xFF),
                        address(coins),
                        keccak256(abi.encodePacked(name, symbol)),
                        keccak256(type(Token).creationCode)
                    )
                )
            )
        );
        
        // 2. Create an ERC20 version
        coins.createToken(id);
        
        // 3. Transfer some tokens
        uint256 transferAmount = initialSupply / 10; // 10% of supply
        coins.transfer(recipient, id, transferAmount);
        
        // 4. Convert some to ERC20
        uint256 tokenizeAmount = initialSupply / 5; // 20% of supply
        coins.tokenize(id, tokenizeAmount);
        
        // 5. Convert back from ERC20
        coins.untokenize(id, tokenizeAmount / 2);
        
        // 6. Update metadata
        coins.setMetadata(id, string(abi.encodePacked(tokenURI, "/updated")));
        
        // 7. Burn some tokens
        uint256 burnAmount = initialSupply / 20; // 5% of supply
        coins.burn(id, burnAmount);
        
        // 8. Check final state
        address owner = coins.ownerOf(id);
        uint256 finalSupply = coins.totalSupply(id);
        uint256 finalBalance = coins.balanceOf(msg.sender, id);
        uint256 recipientBalance = coins.balanceOf(recipient, id);
        
        require(owner == msg.sender, "Owner should be msg.sender");
        require(finalSupply == initialSupply - burnAmount, "Supply calculation incorrect");
        require(finalBalance == initialSupply - transferAmount - tokenizeAmount / 2 - burnAmount, "Balance calculation incorrect");
        require(recipientBalance == transferAmount, "Recipient balance incorrect");
    }
}