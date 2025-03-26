// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";
import {Coins, Token} from "../src/Coins.sol";
import {MockERC20} from "@solady/test/utils/mocks/MockERC20.sol";

error OnlyExternal();
error Unauthorized();
error InvalidMetadata();

contract CoinsTest is Test {
    event MetadataSet(uint256 indexed);
    event ERC20Created(uint256 indexed);
    event OwnershipTransferred(uint256 indexed);

    event OperatorSet(address indexed, address indexed, bool);
    event Approval(address indexed, address indexed, uint256 indexed, uint256);
    event Transfer(address, address indexed, address indexed, uint256 indexed, uint256);

    event Approval(address indexed, address indexed, uint256);
    event Transfer(address indexed, address indexed, uint256);

    Coins public coins;

    // Test accounts
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // Test coin parameters
    string constant NAME = "Test Coin";
    string constant SYMBOL = "TEST";
    string constant TOKEN_URI = "https://example.com/token/test";
    uint256 constant INITIAL_SUPPLY = 1_000_000 * 1e18;

    // Computed coin ID based on parameters
    uint256 public coinId;

    function _predictAddress(bytes32 _salt) internal view returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xFF), address(coins), _salt, keccak256(type(Token).creationCode)
                        )
                    )
                )
            )
        );
    }

    function setUp() public {
        vm.startPrank(deployer);
        coins = new Coins();

        // Create a test coin
        coins.create(NAME, SYMBOL, TOKEN_URI, deployer, INITIAL_SUPPLY);

        // Calculate the expected coin ID
        coinId = uint160(_predictAddress(keccak256(abi.encodePacked(NAME, SYMBOL))));
        //console.log("coinId", address(uint160(coinId)));
        vm.stopPrank();
    }

    // COIN CREATION TESTS

    function test_newCoinGas() public {
        coins.create("YES", "YES", "YES", deployer, INITIAL_SUPPLY);
    }

    function test_CoinCreation() public view {
        // Verify owner
        assertEq(coins.ownerOf(coinId), deployer);

        // Verify supply
        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY);
    }

    function test_RevertWhen_CreatingDuplicateCoin() public {
        vm.prank(alice);
        // Should revert when trying to create a coin with same parameters
        vm.expectRevert();
        coins.create(NAME, SYMBOL, TOKEN_URI, alice, INITIAL_SUPPLY);
    }

    function test_RevertWhen_CreatingWithEmptyURI() public {
        vm.prank(alice);
        // Should revert when URI is empty
        vm.expectRevert(InvalidMetadata.selector);
        coins.create(NAME, SYMBOL, "", alice, INITIAL_SUPPLY);
    }

    // COIN METADATA TESTS

    function test_MetadataAccessors() public view {
        assertEq(coins.name(coinId), NAME);
        assertEq(coins.symbol(coinId), SYMBOL);
        assertEq(coins.tokenURI(coinId), TOKEN_URI);
        assertEq(coins.decimals(coinId), 18);
    }

    function test_SetMetadata() public {
        string memory newTokenUri = "https://example.com/token/updated";

        vm.prank(deployer);
        coins.setMetadata(coinId, newTokenUri);

        assertEq(coins.tokenURI(coinId), newTokenUri);

        // Calculate the new coin ID to verify it's still the same coin
        uint256 newCoinId = uint160(_predictAddress(keccak256(abi.encodePacked(NAME, SYMBOL))));

        // Verify that changing metadata doesn't create a new coin ID
        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY);
        assertEq(coins.balanceOf(deployer, newCoinId), INITIAL_SUPPLY);
    }

    function test_RevertWhen_UnauthorizedMetadataUpdate() public {
        vm.prank(alice);
        // Should revert when non-owner tries to update metadata
        vm.expectRevert(); // Just tests for any revert
        coins.setMetadata(coinId, "https://evil.com");
    }

    // OWNERSHIP TESTS

    function test_TransferOwnership() public {
        vm.prank(deployer);
        coins.transferOwnership(coinId, alice);

        assertEq(coins.ownerOf(coinId), alice);

        // Verify new owner can update metadata
        vm.prank(alice);
        coins.setMetadata(coinId, "https://alice.com");

        // Original owner should no longer have permission
        vm.expectRevert();
        vm.prank(deployer);
        coins.setMetadata(coinId, "https://deployer.com");
    }

    function test_RevertWhen_UnauthorizedOwnershipTransfer() public {
        vm.prank(bob);
        // Should revert when non-owner tries to transfer ownership
        vm.expectRevert();
        coins.transferOwnership(coinId, bob);
    }

    // MINT/BURN TESTS

    function test_Mint() public {
        uint256 mintAmount = 500 * 1e18;

        vm.prank(deployer);
        coins.mint(alice, coinId, mintAmount);

        assertEq(coins.balanceOf(alice, coinId), mintAmount);
        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY);
        assertEq(coins.totalSupply(coinId), INITIAL_SUPPLY + mintAmount);
    }

    function test_RevertWhen_UnauthorizedMint() public {
        vm.prank(alice);
        // Should revert when non-owner tries to mint
        vm.expectRevert();
        coins.mint(alice, coinId, 1000 * 1e18);
    }

    function test_Burn() public {
        uint256 burnAmount = 100 * 1e18;

        vm.prank(deployer);
        coins.burn(coinId, burnAmount);

        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY - burnAmount);
        assertEq(coins.totalSupply(coinId), INITIAL_SUPPLY - burnAmount);
    }

    function test_UserCanBurnOwnTokens() public {
        uint256 transferAmount = 200 * 1e18;
        uint256 burnAmount = 50 * 1e18;

        // Transfer some tokens to bob
        vm.prank(deployer);
        coins.transfer(bob, coinId, transferAmount);

        // Bob burns some of his tokens
        vm.prank(bob);
        coins.burn(coinId, burnAmount);

        assertEq(coins.balanceOf(bob, coinId), transferAmount - burnAmount);
        assertEq(coins.totalSupply(coinId), INITIAL_SUPPLY - burnAmount);
    }

    // TRANSFER TESTS

    function test_Transfer() public {
        uint256 transferAmount = 300 * 1e18;

        vm.prank(deployer);
        coins.transfer(alice, coinId, transferAmount);

        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY - transferAmount);
        assertEq(coins.balanceOf(alice, coinId), transferAmount);
    }

    function test_TransferFrom() public {
        uint256 transferAmount = 250 * 1e18;

        // Approve bob to transfer on behalf of deployer
        vm.prank(deployer);
        coins.approve(bob, coinId, transferAmount);

        // Bob transfers tokens from deployer to alice
        vm.prank(bob);
        coins.transferFrom(deployer, alice, coinId, transferAmount);

        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY - transferAmount);
        assertEq(coins.balanceOf(alice, coinId), transferAmount);
        assertEq(coins.allowance(deployer, bob, coinId), 0);
    }

    function test_RevertWhen_InsufficientAllowance() public {
        // Bob tries to transfer tokens without approval
        vm.prank(bob);
        vm.expectRevert();
        coins.transferFrom(deployer, alice, coinId, 100 * 1e18);
    }

    // Multiple coins tests

    function test_MultipleCoins() public {
        // Create another coin with a different owner
        string memory name2 = "Second Coin";
        string memory symbol2 = "SEC";
        string memory tokenUri2 = "https://example.com/token/second";
        uint256 supply2 = 500_000 * 1e18;

        vm.prank(alice);
        coins.create(name2, symbol2, tokenUri2, alice, supply2);

        uint256 coinId2 = uint160(_predictAddress(keccak256(abi.encodePacked(name2, symbol2))));

        // Verify both coins exist with correct owners and balances
        assertEq(coins.ownerOf(coinId), deployer);
        assertEq(coins.ownerOf(coinId2), alice);

        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY);
        assertEq(coins.balanceOf(alice, coinId2), supply2);

        // Verify each owner can only mint their own coin
        vm.prank(deployer);
        coins.mint(bob, coinId, 1000 * 1e18);

        vm.prank(alice);
        coins.mint(bob, coinId2, 2000 * 1e18);

        assertEq(coins.balanceOf(bob, coinId), 1000 * 1e18);
        assertEq(coins.balanceOf(bob, coinId2), 2000 * 1e18);
    }

    function test_ExternalToken() public {
        // Create an external token
        vm.startPrank(deployer);
        MockERC20 mockToken = new MockERC20("Test Token", "TEST", 18);
        mockToken.mint(deployer, 1000 * 1e18);
        mockToken.approve(address(coins), 1000 * 1e18);
        coins.wrap(Token(address(mockToken)), 1000 * 1e18);
        coins.unwrap(Token(address(mockToken)), 1000 * 1e18);
        vm.stopPrank();
    }

    function test_MaximumAllowance() public {
        uint256 maxAllowance = type(uint256).max;

        vm.startPrank(deployer);
        coins.approve(alice, coinId, maxAllowance);

        // Transfer should not reduce allowance when it's set to max
        vm.startPrank(alice);
        coins.transferFrom(deployer, bob, coinId, 1000 * 1e18);
        assertEq(coins.allowance(deployer, alice, coinId), maxAllowance);
        vm.stopPrank();
    }

    function test_OperatorApproval() public {
        vm.startPrank(deployer);

        // Set bob as an operator for deployer
        coins.setOperator(bob, true);
        assertEq(coins.isOperator(deployer, bob), true);

        // Bob should be able to transfer without specific approval
        vm.stopPrank();
        vm.prank(bob);
        coins.transferFrom(deployer, alice, coinId, 500 * 1e18);

        // Verify balance changes
        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY - 500 * 1e18);
        assertEq(coins.balanceOf(alice, coinId), 500 * 1e18);
    }

    function test_RevokeOperator() public {
        vm.startPrank(deployer);

        // Set bob as an operator
        coins.setOperator(bob, true);

        // Revoke operator status
        coins.setOperator(bob, false);
        assertEq(coins.isOperator(deployer, bob), false);

        vm.stopPrank();

        // Bob should no longer be able to transfer
        vm.startPrank(bob);
        vm.expectRevert();
        coins.transferFrom(deployer, alice, coinId, 100 * 1e18);
        vm.stopPrank();
    }

    function test_TokenURIFallback() public {
        // Create and wrap a mock token
        vm.startPrank(deployer);
        MockERC20 mockToken = new MockERC20("Mock Token", "MOCK", 18);
        mockToken.mint(deployer, 1000 * 1e18);
        mockToken.approve(address(coins), 1000 * 1e18);

        // Wrap the token
        coins.wrap(Token(address(mockToken)), 1000 * 1e18);
        uint256 wrappedId = uint256(uint160(address(mockToken)));

        // Test that name/symbol/decimals fall back to the token's values
        assertEq(coins.name(wrappedId), "Mock Token");
        assertEq(coins.symbol(wrappedId), "MOCK");
        assertEq(coins.decimals(wrappedId), 18);

        // tokenURI should be empty
        assertEq(bytes(coins.tokenURI(wrappedId)).length, 0);

        vm.stopPrank();
    }

    function test_SupportsInterface() public view {
        // Test ERC165 interface
        assertEq(coins.supportsInterface(0x01ffc9a7), true);

        // Test ERC6909 interface
        assertEq(coins.supportsInterface(0x0f632fb3), true);

        // Test for an unsupported interface
        assertEq(coins.supportsInterface(0xffffffff), false);
    }

    function test_TransferEvents() public {
        uint256 transferAmount = 300 * 1e18;

        vm.expectEmit(true, true, true, true);
        emit Transfer(deployer, deployer, alice, coinId, transferAmount);

        vm.prank(deployer);
        coins.transfer(alice, coinId, transferAmount);
    }

    function test_RevertWhen_InsufficientBalance() public {
        uint256 transferAmount = INITIAL_SUPPLY + 1;

        vm.prank(deployer);
        vm.expectRevert();
        coins.transfer(alice, coinId, transferAmount);
    }

    function test_CreateWithZeroSupply() public {
        string memory zeroName = "Zero Supply";
        string memory zeroSymbol = "ZERO";

        vm.prank(alice);
        coins.create(zeroName, zeroSymbol, TOKEN_URI, alice, 0);

        uint256 zeroId = uint160(_predictAddress(keccak256(abi.encodePacked(zeroName, zeroSymbol))));

        assertEq(coins.totalSupply(zeroId), 0);
        assertEq(coins.ownerOf(zeroId), alice);
    }

    function test_RevertWhen_UnwrappingNonWrappedToken() public {
        vm.prank(deployer);
        vm.expectRevert();
        coins.unwrap(Token(address(0x123)), 100 * 1e18);
    }

    function test_DifferentURIForSameNameSymbol() public {
        vm.prank(alice);
        // This should fail because the ID is based on name/symbol, not URI
        vm.expectRevert();
        coins.create(NAME, SYMBOL, "https://different-uri.com", alice, 1000 * 1e18);
    }

    function test_NonStandardDecimalsWrappedToken() public {
        vm.startPrank(deployer);
        // Create a token with 8 decimals
        MockERC20 mockToken = new MockERC20("Decimal Test", "DEC8", 8);
        mockToken.mint(deployer, 1000 * 1e8); // Amount adjusted for decimals
        mockToken.approve(address(coins), 1000 * 1e8);

        // Wrap the token
        coins.wrap(Token(address(mockToken)), 1000 * 1e8);
        uint256 wrappedId = uint256(uint160(address(mockToken)));

        // Test that decimals match the original token
        assertEq(coins.decimals(wrappedId), 8);
        vm.stopPrank();
    }

    function test_MultipleIDOperations() public {
        // Create a second coin
        vm.prank(deployer);
        coins.create("Second Coin", "SEC", "https://second.com", deployer, 500 * 1e18);
        uint256 secondCoinId =
            uint160(_predictAddress(keccak256(abi.encodePacked("Second Coin", "SEC"))));

        // Transfer both coins to alice
        vm.startPrank(deployer);
        coins.transfer(alice, coinId, 100 * 1e18);
        coins.transfer(alice, secondCoinId, 50 * 1e18);
        vm.stopPrank();

        // Verify both transfers succeeded
        assertEq(coins.balanceOf(alice, coinId), 100 * 1e18);
        assertEq(coins.balanceOf(alice, secondCoinId), 50 * 1e18);
    }

    function test_MultipleOwnershipTransfers() public {
        // Create a second coin
        vm.prank(deployer);
        coins.create("Second Coin", "SEC", "https://second.com", deployer, 500 * 1e18);
        uint256 secondCoinId =
            uint160(_predictAddress(keccak256(abi.encodePacked("Second Coin", "SEC"))));

        // Transfer ownership of both coins
        vm.startPrank(deployer);
        coins.transferOwnership(coinId, alice);
        coins.transferOwnership(secondCoinId, bob);
        vm.stopPrank();

        // Verify new owners
        assertEq(coins.ownerOf(coinId), alice);
        assertEq(coins.ownerOf(secondCoinId), bob);

        // Verify new owners can mint
        vm.prank(alice);
        coins.mint(alice, coinId, 100 * 1e18);

        vm.prank(bob);
        coins.mint(bob, secondCoinId, 100 * 1e18);
    }

    function test_ERC20Interactions() public {
        vm.startPrank(deployer);

        // Get the ERC20 token
        Token token = Token(address(uint160(coinId)));

        // Test standard ERC20 functions
        token.approve(alice, 200 * 1e18);
        assertEq(token.allowance(deployer, alice), 200 * 1e18);

        token.transfer(bob, 100 * 1e18);
        assertEq(token.balanceOf(bob), 100 * 1e18);

        vm.stopPrank();

        // Test transferFrom
        vm.prank(alice);
        token.transferFrom(deployer, alice, 200 * 1e18);
        assertEq(token.balanceOf(alice), 200 * 1e18);

        // Fix: Calculate correct expected balance
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - 100 * 1e18 - 200 * 1e18);
    }

    function test_LargeTransferGasUsage() public {
        uint256 largeAmount = INITIAL_SUPPLY / 2;

        // Measure gas for a large transfer
        uint256 gasStart = gasleft();
        vm.prank(deployer);
        coins.transfer(alice, coinId, largeAmount);
        uint256 gasUsed = gasStart - gasleft();

        // Just a simple verification that the transfer succeeded
        assertEq(coins.balanceOf(alice, coinId), largeAmount);

        // Output gas used for analysis
        console.log("Gas used for large transfer:", gasUsed);
    }

    function test_WrappingNonCompliantToken() public {
        // This test would need to be adjusted based on how your system handles non-standard ERC20 tokens
        // For example, tokens with transfer fees or rebasing mechanisms

        vm.startPrank(deployer);

        // Mock a token with non-standard behavior (ideally with a transfer fee mechanism)
        // For this test to be meaningful, you'd need a mock token that implements a fee
        // MockTokenWithFee mockToken = new MockTokenWithFee();

        // For the purpose of this snippet, we'll just use a regular mock
        MockERC20 mockToken = new MockERC20("Fee Token", "FEE", 18);
        mockToken.mint(deployer, 1000 * 1e18);
        mockToken.approve(address(coins), 1000 * 1e18);

        // Wrap the token - the wrap function should handle any discrepancies
        coins.wrap(Token(address(mockToken)), 1000 * 1e18);

        vm.stopPrank();
    }

    // LOOP TESTS

    function test_loop20() public {
        console.log("coinId", address(uint160(coinId)));
        Token token = Token(address(uint160(coinId)));
        vm.startPrank(deployer);
        token.approve(address(coins), 1e18);
        vm.stopPrank();
        console.log("balance", token.balanceOf(deployer));
        console.log("allowance", token.allowance(deployer, address(coins)));
        // Native token should not be wrappable
        console.log("Coin's Balance", token.balanceOf(address(coins)));
        vm.prank(deployer);
        vm.expectRevert(OnlyExternal.selector);
        coins.wrap(token, 1e18);
        console.log("Coin's Balance", token.balanceOf(address(coins)));
    }
}
