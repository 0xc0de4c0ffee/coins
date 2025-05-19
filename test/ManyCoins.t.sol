// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "forge-std/console.sol";

import {Test} from "forge-std/Test.sol";
import {ManyCoins} from "../src/ManyCoins.sol";
import {MockERC20} from "@solady/test/utils/mocks/MockERC20.sol";
import {Token} from "../src/Coins.sol";

contract ManyCoinsTest is Test {
    ManyCoins public manyCoins;
    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;

    // Test accounts
    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // Test parameters
    string constant NAME = "Test Bundle";
    string constant SYMBOL = "BUNDLE";
    string constant TOKEN_URI = "https://example.com/token/bundle";
    uint256 constant INITIAL_SHARES = 1000 * 1e18;

    // Token amounts for the bundle
    uint256 constant TOKEN1_AMOUNT = 100 * 1e18;
    uint256 constant TOKEN2_AMOUNT = 200 * 1e18;
    uint256 constant TOKEN3_AMOUNT = 300 * 1e18;

    // Computed bundle ID
    uint256 public bundleId;

    function _predictAddress(bytes32 _salt) internal view returns (address) {
        // First predict the implementation token address
        address implementation = _predictImplementationAddress();

        // Use the predicted implementation address to calculate the clone address
        bytes memory proxyCode = abi.encodePacked(
            hex"602c3d8160093d39f33d3d3d3d363d3d37363d73",
            implementation,
            hex"5af43d3d93803e602a57fd5bf3"
        );

        // Calculate CREATE2 address
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(manyCoins),
                                _salt,
                                keccak256(proxyCode)
                            )
                        )
                    )
                )
            );
    }

    function _predictImplementationAddress() internal view returns (address) {
        // Predict the implementation token address based on how it's deployed in your contract
        bytes32 salt = keccak256("");
        bytes32 initCodeHash = keccak256(type(Token).creationCode);

        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(manyCoins),
                                salt,
                                initCodeHash
                            )
                        )
                    )
                )
            );
    }

    function setUp() public {
        vm.startPrank(deployer);

        // Deploy ManyCoins contract
        manyCoins = new ManyCoins();

        // Deploy mock tokens
        token1 = new MockERC20("Token 1", "TK1", 18);
        token2 = new MockERC20("Token 2", "TK2", 18);
        token3 = new MockERC20("Token 3", "TK3", 18);

        // Mint a large amount of tokens to deployer for all tests
        uint256 mintAmount = 1_000_000 * 1e18;
        token1.mint(deployer, mintAmount);
        token2.mint(deployer, mintAmount);
        token3.mint(deployer, mintAmount);

        // Approve tokens for ManyCoins
        token1.approve(address(manyCoins), type(uint256).max);
        token2.approve(address(manyCoins), type(uint256).max);
        token3.approve(address(manyCoins), type(uint256).max);

        // Create token arrays for reindex
        Token[] memory tokens = new Token[](3);
        tokens[0] = Token(address(token1));
        tokens[1] = Token(address(token2));
        tokens[2] = Token(address(token3));

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = TOKEN1_AMOUNT;
        amounts[1] = TOKEN2_AMOUNT;
        amounts[2] = TOKEN3_AMOUNT;

        // Create the bundle
        manyCoins.reindex(
            deployer,
            INITIAL_SHARES,
            NAME,
            SYMBOL,
            TOKEN_URI,
            tokens,
            amounts
        );

        // Calculate bundle ID using the prediction function
        bytes32 salt = keccak256(
            abi.encodePacked(NAME, address(manyCoins), SYMBOL, block.chainid)
        );
        bundleId = uint256(uint160(_predictAddress(salt)));

        vm.stopPrank();
    }

    // BUNDLE CREATION TESTS

    function test_BundleCreation() public view {
        // Verify total supply
        assertEq(
            manyCoins.totalSupply(bundleId),
            INITIAL_SHARES,
            "Total supply should be 1000*1e18"
        );

        // Verify balances
        assertEq(manyCoins.balanceOf(deployer, bundleId), INITIAL_SHARES);

        // Verify token balances in ManyCoins
        assertEq(
            token1.balanceOf(address(manyCoins)),
            (TOKEN1_AMOUNT * INITIAL_SHARES) / 1e18,
            "Token 1 balance should be 100*1e18"
        );
        assertEq(
            token2.balanceOf(address(manyCoins)),
            (TOKEN2_AMOUNT * INITIAL_SHARES) / 1e18,
            "Token 2 balance should be 200*1e18"
        );
        assertEq(
            token3.balanceOf(address(manyCoins)),
            (TOKEN3_AMOUNT * INITIAL_SHARES) / 1e18,
            "Token 3 balance should be 300*1e18"
        );
    }

    function test_RevertWhen_CreatingWithEmptyURI() public {
        Token[] memory tokens = new Token[](1);
        tokens[0] = Token(address(token1));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOKEN1_AMOUNT;

        vm.prank(alice);
        vm.expectRevert();
        manyCoins.reindex(
            alice,
            INITIAL_SHARES,
            NAME,
            SYMBOL,
            "",
            tokens,
            amounts
        );
    }

    function test_RevertWhen_TokensAndAmountsMismatch() public {
        Token[] memory tokens = new Token[](2);
        tokens[0] = Token(address(token1));
        tokens[1] = Token(address(token2));

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = TOKEN1_AMOUNT;

        vm.prank(alice);
        vm.expectRevert();
        manyCoins.reindex(
            alice,
            INITIAL_SHARES,
            NAME,
            SYMBOL,
            TOKEN_URI,
            tokens,
            amounts
        );
    }

    // WRAPPING TESTS

    function test_WrapFractionalAmount() public {
        uint256 wrapAmount = 0.5 * 1e18; // Wrap 0.5 units

        vm.startPrank(deployer);

        // Get initial balances
        uint256 initialToken1Balance = token1.balanceOf(deployer);
        uint256 initialToken2Balance = token2.balanceOf(deployer);
        uint256 initialToken3Balance = token3.balanceOf(deployer);

        // Wrap fractional amount
        manyCoins.wrapMany(bundleId, wrapAmount);

        // Calculate expected token amounts
        uint256 expectedToken1Amount = (wrapAmount * TOKEN1_AMOUNT) / 1e18;
        uint256 expectedToken2Amount = (wrapAmount * TOKEN2_AMOUNT) / 1e18;
        uint256 expectedToken3Amount = (wrapAmount * TOKEN3_AMOUNT) / 1e18;

        // Verify token transfers
        assertEq(
            token1.balanceOf(deployer),
            initialToken1Balance - expectedToken1Amount
        );
        assertEq(
            token2.balanceOf(deployer),
            initialToken2Balance - expectedToken2Amount
        );
        assertEq(
            token3.balanceOf(deployer),
            initialToken3Balance - expectedToken3Amount
        );

        // Verify bundle balance
        assertEq(
            manyCoins.balanceOf(deployer, bundleId),
            INITIAL_SHARES + wrapAmount
        );

        vm.stopPrank();
    }

    function test_UnwrapFractionalAmount() public {
        uint256 wrapAmount = 1 * 1e18; // First wrap 1 unit
        uint256 unwrapAmount = 0.3 * 1e18; // Then unwrap 0.3 units

        vm.startPrank(deployer);

        // First wrap some tokens
        manyCoins.wrapMany(bundleId, wrapAmount);

        // Get balances before unwrap
        uint256 beforeToken1Balance = token1.balanceOf(deployer);
        uint256 beforeToken2Balance = token2.balanceOf(deployer);
        uint256 beforeToken3Balance = token3.balanceOf(deployer);

        // Unwrap fractional amount
        manyCoins.unwrapMany(bundleId, unwrapAmount);

        // Calculate expected token amounts
        uint256 expectedToken1Amount = (unwrapAmount * TOKEN1_AMOUNT) / 1e18;
        uint256 expectedToken2Amount = (unwrapAmount * TOKEN2_AMOUNT) / 1e18;
        uint256 expectedToken3Amount = (unwrapAmount * TOKEN3_AMOUNT) / 1e18;

        // Verify token transfers
        assertEq(
            token1.balanceOf(deployer),
            beforeToken1Balance + expectedToken1Amount
        );
        assertEq(
            token2.balanceOf(deployer),
            beforeToken2Balance + expectedToken2Amount
        );
        assertEq(
            token3.balanceOf(deployer),
            beforeToken3Balance + expectedToken3Amount
        );

        // Verify bundle balance
        assertEq(
            manyCoins.balanceOf(deployer, bundleId),
            INITIAL_SHARES + wrapAmount - unwrapAmount
        );

        vm.stopPrank();
    }

    function test_RevertWhen_WrappingNonBundle() public {
        // Create a regular token
        vm.startPrank(deployer);
        MockERC20 regularToken = new MockERC20("Regular", "REG", 18);
        regularToken.mint(deployer, 1000 * 1e18);
        regularToken.approve(address(manyCoins), 1000 * 1e18);

        // Try to wrap it as a bundle
        uint256 regularTokenId = uint256(uint160(address(regularToken)));
        vm.expectRevert();
        manyCoins.wrapMany(regularTokenId, 1e18);

        vm.stopPrank();
    }

    function test_RevertWhen_UnwrappingMoreThanBalance() public {
        // Create a new bundle with a small number of shares
        Token[] memory tokens = new Token[](3);
        tokens[0] = Token(address(token1));
        tokens[1] = Token(address(token2));
        tokens[2] = Token(address(token3));

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = TOKEN1_AMOUNT;
        amounts[1] = TOKEN2_AMOUNT;
        amounts[2] = TOKEN3_AMOUNT;

        uint256 smallShares = 1;
        string memory newName = "Small Bundle";
        string memory newSymbol = "SMB";
        string memory newURI = "https://example.com/token/smallbundle";

        vm.startPrank(deployer);
        manyCoins.reindex(
            deployer,
            smallShares,
            newName,
            newSymbol,
            newURI,
            tokens,
            amounts
        );
        bytes32 salt = keccak256(
            abi.encodePacked(
                newName,
                address(manyCoins),
                newSymbol,
                block.chainid
            )
        );
        uint256 smallBundleId = uint256(uint160(_predictAddress(salt)));

        // Wrap a small amount
        uint256 wrapAmount = 1 * 1e18;
        manyCoins.wrapMany(smallBundleId, wrapAmount);

        // Try to unwrap more than balance
        uint256 unwrapAmount = 3 * 1e18;
        vm.expectRevert(ManyCoins.InsufficientBalance.selector);
        manyCoins.unwrapMany(smallBundleId, unwrapAmount);
        vm.stopPrank();
    }

    function test_TransferAndUnwrap() public {
        uint256 wrapAmount = 1 * 1e18;
        uint256 transferAmount = 0.555555 * 1e18;
        uint256 unwrapAmount = 0.3 * 1e18;

        vm.startPrank(deployer);

        // Wrap tokens
        manyCoins.wrapMany(bundleId, wrapAmount);

        // Transfer some to alice
        manyCoins.transfer(alice, bundleId, transferAmount);

        vm.stopPrank();

        // Alice unwraps some tokens
        vm.startPrank(alice);

        // Get balances before unwrap
        uint256 beforeToken1Balance = token1.balanceOf(alice);
        uint256 beforeToken2Balance = token2.balanceOf(alice);
        uint256 beforeToken3Balance = token3.balanceOf(alice);

        manyCoins.unwrapMany(bundleId, unwrapAmount);

        // Calculate expected token amounts
        uint256 expectedToken1Amount = (unwrapAmount * TOKEN1_AMOUNT) / 1e18;
        uint256 expectedToken2Amount = (unwrapAmount * TOKEN2_AMOUNT) / 1e18;
        uint256 expectedToken3Amount = (unwrapAmount * TOKEN3_AMOUNT) / 1e18;

        // Verify token transfers
        assertEq(
            token1.balanceOf(alice),
            beforeToken1Balance + expectedToken1Amount
        );
        assertEq(
            token2.balanceOf(alice),
            beforeToken2Balance + expectedToken2Amount
        );
        assertEq(
            token3.balanceOf(alice),
            beforeToken3Balance + expectedToken3Amount
        );

        // Verify bundle balances
        assertEq(
            manyCoins.balanceOf(deployer, bundleId),
            INITIAL_SHARES + wrapAmount - transferAmount
        );
        assertEq(
            manyCoins.balanceOf(alice, bundleId),
            transferAmount - unwrapAmount
        );

        vm.stopPrank();
    }

    function test_WrapVerySmallFractionalAmount() public {
        uint256 wrapAmount = 0.3333333333 * 1e18; // Wrap a very small fractional amount

        vm.startPrank(deployer);

        // Get initial balances
        uint256 initialToken1Balance = token1.balanceOf(deployer);
        uint256 initialToken2Balance = token2.balanceOf(deployer);
        uint256 initialToken3Balance = token3.balanceOf(deployer);

        // Wrap the very small fractional amount
        manyCoins.wrapMany(bundleId, wrapAmount);

        // Calculate expected token amounts
        uint256 expectedToken1Amount = (wrapAmount * TOKEN1_AMOUNT) / 1e18;
        uint256 expectedToken2Amount = (wrapAmount * TOKEN2_AMOUNT) / 1e18;
        uint256 expectedToken3Amount = (wrapAmount * TOKEN3_AMOUNT) / 1e18;

        // Verify token transfers
        assertEq(
            token1.balanceOf(deployer),
            initialToken1Balance - expectedToken1Amount
        );
        assertEq(
            token2.balanceOf(deployer),
            initialToken2Balance - expectedToken2Amount
        );
        assertEq(
            token3.balanceOf(deployer),
            initialToken3Balance - expectedToken3Amount
        );

        // Verify bundle balance
        assertEq(
            manyCoins.balanceOf(deployer, bundleId),
            INITIAL_SHARES + wrapAmount
        );

        vm.stopPrank();
    }
}
