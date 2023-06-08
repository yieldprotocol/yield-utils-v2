// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/token/TokenUpgrade.sol";
import "../src/interfaces/ITokenUpgrade.sol";
import { ERC20Mock } from "../src/mocks/ERC20Mock.sol";
import { TestExtensions } from "./utils/TestExtensions.sol";
import { TestConstants } from "./utils/TestConstants.sol";


using stdStorage for StdStorage;

abstract contract DeployedState is Test, TestExtensions, TestConstants {

    struct TokenIn {
        IERC20 reverse;
        uint96 ratio;
        uint256 balance;
    }

    struct TokenOut {
        IERC20 reverse;
        uint256 balance;     
    }

    event Registered(
        IERC20 indexed tokenIn, 
        IERC20 indexed tokenOut, 
        uint256 tokenInBalance, 
        uint256 tokenOutBalance, 
        uint96 ratio, 
        bytes32 merkleRoot
    );
    event Unregistered(
        IERC20 indexed tokenIn, 
        IERC20 indexed tokenOut, 
        uint256 tokenInBalance, 
        uint256 tokenOutBalance
    );
    event Upgraded(
        IERC20 indexed tokenIn, 
        IERC20 indexed tokenOut, 
        uint256 tokenInAmount, 
        uint256 tokenOutAmount
    );
    event Extracted(IERC20 indexed tokenIn, uint256 tokenInBalance);
    event Recovered(IERC20 indexed token, uint256 recovered);

    IERC20 public tokenIn;
    IERC20 public tokenOut;
    IERC20 public tokenOther;
    TokenUpgrade public tokenUpgrade;
    // From generator config
    address whitelisted = 0x185a4dc360CE69bDCceE33b3784B0282f7961aea;
    bytes32 tosHash = 0x9f6699a0964b1bd6fe6c9fb8bebea236c08311ddd25781bbf5d372d00d32936b;
    bytes32 merkleRoot = 0x6e1cf800e87b91489637cdf163e341d93bff0ab519bcbad6725ff29ccbdf7d2a;
    bytes32[] proof;
    bytes32[] invalidProof;

    address user;
    address other;
    address admin;
    address me;

    function setUp() public virtual {

        //... Users ...
        user = address(1);
        other = address(2);
        admin = address(3);
        me = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

        tokenIn = IERC20(address(new ERC20Mock("Token In", "TIN")));
        tokenOut = IERC20(address(new ERC20Mock("Token Out", "TOU")));
        tokenOther = IERC20(address(new ERC20Mock("Token Other", "TOT")));
        tokenUpgrade = new TokenUpgrade();

        tokenUpgrade.grantRole(TokenUpgrade.register.selector, admin);
        tokenUpgrade.grantRole(TokenUpgrade.unregister.selector, admin);
        tokenUpgrade.grantRole(TokenUpgrade.extract.selector, admin);
        tokenUpgrade.grantRole(TokenUpgrade.recover.selector, admin);

        proof = new bytes32[](1);
        proof[0] = 0x2582e1a57b72c0e7723d34122d5633550f42d7317b1e426a7664ac004b2e605c;
        invalidProof = new bytes32[](1);
        invalidProof[0] = 0x0000000000000000000000000000000000000000000000000000000000000000;

        vm.label(user, "user");
        vm.label(other, "other");
        vm.label(admin, "admin");
        vm.label(me, "me");
        vm.label(address(tokenIn), "TokenIn");
        vm.label(address(tokenOut), "TokenOut");
    }
}

contract DeployedTest is DeployedState {

    function testRegisterRevertsOnSameToken() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.SameToken.selector, address(tokenIn)));
        vm.prank(admin);
        tokenUpgrade.register(tokenIn, tokenIn, merkleRoot);
    }

    function testUnregisterRevertsIfNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.TokenInNotRegistered.selector, address(tokenIn)));
        vm.prank(admin);
        tokenUpgrade.unregister(tokenIn, other);
    }

    function testExtractRevertsIfNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.TokenInNotRegistered.selector, address(tokenIn)));
        vm.prank(admin);
        tokenUpgrade.extract(tokenIn, other);
    }

    function testRegister() public {
        uint256 tokenInSupply = 100e18;
        uint256 tokenOutSupply = 101e18;
        ERC20Mock(address(tokenIn)).mint(user, tokenInSupply);
        ERC20Mock(address(tokenOut)).mint(address(tokenUpgrade), tokenOutSupply);
        uint96 ratio = uint96(tokenOutSupply * 1e18 / tokenInSupply);
        vm.expectEmit(false, false, false, false);
        emit Registered(tokenIn, tokenOut, tokenInSupply, tokenOutSupply, ratio, merkleRoot);

        vm.prank(admin);
        tokenUpgrade.register(tokenIn, tokenOut, merkleRoot);

        ITokenUpgrade.TokenIn memory tokenIn_ = ITokenUpgrade(address(tokenUpgrade)).tokensIn(tokenIn);
        ITokenUpgrade.TokenOut memory tokenOut_ = ITokenUpgrade(address(tokenUpgrade)).tokensOut(tokenOut);
        assertEq(tokenIn_.ratio, ratio);
        assertEq(tokenIn_.balance, 0);
        assertEq(address(tokenIn_.reverse), address(tokenOut));
        assertEq(tokenOut_.balance, tokenOutSupply);
        assertEq(address(tokenOut_.reverse), address(tokenIn));
    }
}

abstract contract RegisteredState is DeployedState {

    function setUp() public virtual override {
        super.setUp();
        uint256 tokenInSupply = 100e18;
        uint256 tokenOutSupply = 101e18;
        ERC20Mock(address(tokenIn)).mint(user, tokenInSupply);
        ERC20Mock(address(tokenIn)).mint(whitelisted, tokenInSupply);
        ERC20Mock(address(tokenOut)).mint(address(tokenUpgrade), tokenOutSupply);
        vm.prank(admin);
        tokenUpgrade.register(tokenIn, tokenOut, merkleRoot);
    }
}

contract RegisteredTest is RegisteredState {

    /// @dev Test you can't register the same token twice as tokenIn
    function testRegisterRevertsOnSameTokenIn() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.TokenInAlreadyRegistered.selector, address(tokenIn)));
        vm.prank(admin);
        tokenUpgrade.register(tokenIn, tokenOther, merkleRoot);
    }

    /// @dev Test you can't register the same token twice as tokenOut
    function testRegisterRevertsOnSameTokenOut() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.TokenOutAlreadyRegistered.selector, address(tokenOut)));
        vm.prank(admin);
        tokenUpgrade.register(tokenOther, tokenOut, merkleRoot);
    }

    function testRecoverRevertsIfTokenIn() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.TokenInAlreadyRegistered.selector, address(tokenIn)));
        vm.prank(admin);
        tokenUpgrade.recover(tokenIn, other);
    }

    function testRecoverRevertsIfTokenOut() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.TokenOutAlreadyRegistered.selector, address(tokenOut)));
        vm.prank(admin);
        tokenUpgrade.recover(tokenOut, other);
    }

    function testUpgradeRevertsIfNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(TokenUpgrade.TokenInNotRegistered.selector, address(tokenOther)));
        vm.prank(whitelisted);
        bytes32 acceptanceToken = keccak256(abi.encodePacked(whitelisted, tosHash));
        tokenUpgrade.upgrade(tokenOther, acceptanceToken, whitelisted, 100e18, proof);
    }

    function testUpgradeRevertIfInvalidProof() public {
        vm.startPrank(whitelisted);
        tokenIn.approve(address(tokenUpgrade), 100e18);
        bytes32 acceptanceToken = keccak256(abi.encodePacked(whitelisted, tosHash));
        vm.expectRevert(TokenUpgrade.NotInMerkleTree.selector);
        tokenUpgrade.upgrade(tokenIn, acceptanceToken, whitelisted, 100e18, invalidProof);
        vm.stopPrank();
    }

    function testUpgradeReversOnInvalidAcceptanceToken() public {
        vm.startPrank(user);
        tokenIn.approve(address(tokenUpgrade), 100e18);
        bytes32 acceptanceToken = keccak256(abi.encodePacked(whitelisted, tosHash));
        vm.expectRevert(TokenUpgrade.InvalidAcceptanceToken.selector);
        tokenUpgrade.upgrade(tokenIn, acceptanceToken, user, 100e18, proof);
        vm.stopPrank();
    }

    function testUpgradeRevertOnInvalidSender() public {
        vm.startPrank(user);
        tokenIn.approve(address(tokenUpgrade), 100e18);
        bytes32 acceptanceToken = keccak256(abi.encodePacked(user, tosHash));
        vm.expectRevert(TokenUpgrade.NotInMerkleTree.selector);
        tokenUpgrade.upgrade(tokenIn, acceptanceToken, user, 100e18, proof);
        vm.stopPrank();
    }

    function testUpgrade() public {
        ITokenUpgrade.TokenIn memory tokenIn_ = ITokenUpgrade(address(tokenUpgrade)).tokensIn(tokenIn);
        ITokenUpgrade.TokenOut memory tokenOut_ = ITokenUpgrade(address(tokenUpgrade)).tokensOut(tokenOut);
        
        uint256 tokenInAmount = tokenIn.balanceOf(whitelisted);
        assertGt(tokenInAmount, 0);

        uint256 expectedTokenInBalance = tokenIn_.balance + tokenInAmount;
        uint256 expectedTokenOut = tokenInAmount * tokenIn_.ratio / 1e18;
        uint256 expectedTokenOutBalance = tokenOut_.balance - expectedTokenOut;

        vm.startPrank(whitelisted);
        tokenIn.approve(address(tokenUpgrade), 100e18);

        vm.expectEmit(true, true, true, true);
        emit Upgraded(tokenIn, tokenOut, tokenInAmount, expectedTokenOut);

        bytes32 acceptanceToken = keccak256(abi.encodePacked(whitelisted, tosHash));
        tokenUpgrade.upgrade(tokenIn, acceptanceToken, whitelisted, 100e18, proof);
        vm.stopPrank();

        tokenIn_ = ITokenUpgrade(address(tokenUpgrade)).tokensIn(tokenIn);
        tokenOut_ = ITokenUpgrade(address(tokenUpgrade)).tokensOut(tokenOut);

        assertEq(tokenIn_.balance, expectedTokenInBalance);
        assertEq(tokenOut_.balance, expectedTokenOutBalance);
        assertEq(tokenOut.balanceOf(whitelisted), expectedTokenOut);
    }

    function testRecover() public {
        uint256 tokenAmount = 100e18;
        cash(tokenOther, address(tokenUpgrade), tokenAmount);

        vm.startPrank(admin);

        vm.expectEmit(true, true, true, false);
        emit Recovered(tokenOther, tokenAmount);

        tokenUpgrade.recover(tokenOther, other);
        vm.stopPrank();

        assertEq(tokenOther.balanceOf(other), tokenAmount);
    }
}

abstract contract UpgradedState is RegisteredState {
    function setUp() public virtual override {
        super.setUp();
        
        uint256 tokenInAmount = tokenIn.balanceOf(whitelisted);
        assertGt(tokenInAmount, 0);

        vm.startPrank(whitelisted);
        tokenIn.approve(address(tokenUpgrade), tokenInAmount);
        bytes32 acceptanceToken = keccak256(abi.encodePacked(whitelisted, tosHash));
        tokenUpgrade.upgrade(tokenIn, acceptanceToken, whitelisted, tokenInAmount, proof);
        vm.stopPrank();
    }
}

contract UpgradedTest is UpgradedState {
    function testUnregister() public {
        uint256 tokenInBalance = tokenIn.balanceOf(address(tokenUpgrade));
        uint256 tokenOutBalance = tokenOut.balanceOf(address(tokenUpgrade));

        vm.expectEmit(true, true, true, true);
        emit Unregistered(tokenIn, tokenOut, tokenInBalance, tokenOutBalance);

        vm.startPrank(admin);
        tokenUpgrade.unregister(tokenIn, other);

        assertEq(tokenIn.balanceOf(other), tokenInBalance);
        assertEq(tokenOut.balanceOf(other), tokenOutBalance);

        ITokenUpgrade.TokenIn memory tokenIn_ = ITokenUpgrade(address(tokenUpgrade)).tokensIn(tokenIn);
        ITokenUpgrade.TokenOut memory tokenOut_ = ITokenUpgrade(address(tokenUpgrade)).tokensOut(tokenOut);

        assertEq(tokenIn_.ratio, 0);
        assertEq(tokenIn_.balance, 0);
        assertEq(tokenOut_.balance, 0);
        assertEq(address(tokenIn_.reverse), address(0));
        assertEq(address(tokenOut_.reverse), address(0));
    }

    function testExtract() public {
        uint256 tokenInBalance = tokenIn.balanceOf(address(tokenUpgrade));

        vm.expectEmit(true, true, true, false);
        emit Extracted(tokenIn, tokenInBalance);

        vm.startPrank(admin);
        tokenUpgrade.extract(tokenIn, other);

        assertEq(tokenIn.balanceOf(other), tokenInBalance);

        ITokenUpgrade.TokenIn memory tokenIn_ = ITokenUpgrade(address(tokenUpgrade)).tokensIn(tokenIn);

        assertEq(tokenIn_.balance, 0);
    }
}