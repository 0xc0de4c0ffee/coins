// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {Coins} from "../src/Coins.sol";

error Unauthorized();
error AlreadyCreated();
error InvalidMetadata();

contract CoinsTest is Test {
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

    function setUp() public {
        vm.startPrank(deployer);
        coins = new Coins();

        // Create a test coin
        coins.create(NAME, SYMBOL, TOKEN_URI, deployer, INITIAL_SUPPLY);

        // Calculate the expected coin ID
        coinId = uint256(keccak256(abi.encodePacked(NAME, SYMBOL, TOKEN_URI)));

        vm.stopPrank();
    }

    // COIN CREATION TESTS

    function test_CoinCreation() public view {
        // Verify owner
        assertEq(coins.ownerOf(coinId), deployer);

        // Verify supply
        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY);
    }

    function test_RevertWhen_CreatingDuplicateCoin() public {
        vm.prank(alice);
        // Should revert when trying to create a coin with same parameters
        vm.expectRevert(AlreadyCreated.selector);
        coins.create(NAME, SYMBOL, TOKEN_URI, alice, INITIAL_SUPPLY);
    }

    function test_RevertWhen_CreatingWithEmptySymbol() public {
        vm.prank(alice);
        // Should revert when symbol is empty
        vm.expectRevert(InvalidMetadata.selector);
        coins.create(NAME, "", TOKEN_URI, alice, INITIAL_SUPPLY);
    }

    // COIN METADATA TESTS

    function test_MetadataAccessors() public view {
        assertEq(coins.name(coinId), NAME);
        assertEq(coins.symbol(coinId), SYMBOL);
        assertEq(coins.tokenURI(coinId), TOKEN_URI);
        assertEq(coins.decimals(coinId), 18);
    }

    function test_SetMetadata() public {
        string memory newName = "Updated Coin";
        string memory newSymbol = "UPD";
        string memory newTokenUri = "https://example.com/token/updated";

        vm.prank(deployer);
        coins.setMetadata(coinId, newName, newSymbol, newTokenUri);

        assertEq(coins.name(coinId), newName);
        assertEq(coins.symbol(coinId), newSymbol);
        assertEq(coins.tokenURI(coinId), newTokenUri);

        // Calculate the new coin ID to verify it's still the same coin
        uint256 newCoinId = uint256(keccak256(abi.encodePacked(newName, newSymbol, newTokenUri)));

        // Verify that changing metadata doesn't create a new coin ID
        assertEq(coins.balanceOf(deployer, coinId), INITIAL_SUPPLY);
        assertEq(coins.balanceOf(deployer, newCoinId), 0);
    }

    function test_RevertWhen_UnauthorizedMetadataUpdate() public {
        vm.prank(alice);
        // Should revert when non-owner tries to update metadata
        vm.expectRevert(); // Just tests for any revert
        coins.setMetadata(coinId, "Hacked Coin", "HACK", "https://evil.com");
    }

    // OWNERSHIP TESTS

    function test_TransferOwnership() public {
        vm.prank(deployer);
        coins.transferOwnership(coinId, alice);

        assertEq(coins.ownerOf(coinId), alice);

        // Verify new owner can update metadata
        vm.prank(alice);
        coins.setMetadata(coinId, "Alice Coin", "ALICE", "https://alice.com");

        // Original owner should no longer have permission
        vm.expectRevert();
        vm.prank(deployer);
        coins.setMetadata(coinId, "Deployer Coin", "DEPLOY", "https://deployer.com");
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

        uint256 coinId2 = uint256(keccak256(abi.encodePacked(name2, symbol2, tokenUri2)));

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
}
