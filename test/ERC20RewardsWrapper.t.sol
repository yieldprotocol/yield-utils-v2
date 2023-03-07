// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/token/IERC20.sol";
import { ERC20, ERC20Mock } from "../src/mocks/ERC20Mock.sol";
import { ERC20RewardsWrapper } from "../src/token/ERC20RewardsWrapper.sol";
import { TestExtensions } from "./utils/TestExtensions.sol";
import { TestConstants } from "./utils/TestConstants.sol";

using stdStorage for StdStorage;

abstract contract Deployed is Test, TestExtensions, TestConstants {

    event AssetSet(ERC20 newAsset);
    event Skimmed(ERC20 token, address to);

    ERC20 public asset;
    uint256 public assetUnit;
    ERC20RewardsWrapper public vault;
    uint256 public vaultUnit;

    address user;
    address other;
    address admin;
    address me;


    function setUp() public virtual {

        user = address(1);
        other = address(2);
        admin = address(3);
        me = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

        vault = new ERC20RewardsWrapper("Rewards Wrapper", "RWP", 18);
        vaultUnit = 10 ** ERC20Mock(address(vault)).decimals();
        asset = ERC20(address(new ERC20Mock("Rewards Token", "REW")));
        assetUnit = 10 ** ERC20Mock(address(asset)).decimals();

        vault.grantRole(ERC20RewardsWrapper.set.selector, admin);
        vault.grantRole(ERC20RewardsWrapper.mint.selector, admin);
        vault.grantRole(ERC20RewardsWrapper.skim.selector, admin);

        vm.label(user, "user");
        vm.label(other, "other");
        vm.label(admin, "admin");
        vm.label(me, "me");
        vm.label(address(vault), "vault");
        vm.label(address(asset), "asset");
    }
}

contract DeployedTest is Deployed {

    function testSetAsset(ERC20 token) public {
        vm.expectEmit(true, false, false, false);
        emit AssetSet(token);

        vm.prank(admin);
        vault.set(token);

        assertEq(address(vault.asset()), address(token));
    }

    function testConvertToSharesRevertsIfAssetNotSet() public {
        vm.expectRevert("Asset not set");
        vault.convertToShares(0);
    }

    function testConvertToAssetsRevertsIfAssetNotSet() public {
        vm.expectRevert("Asset not set");
        vault.convertToAssets(0);
    }

    function testSkim(address to, uint amount) public {
        ERC20 token = ERC20(address(new ERC20Mock("Skim Token", "SKM")));
        vm.expectEmit(true, false, false, false);
        emit Skimmed(token, to);

        cash(token, address(vault), amount);

        vm.prank(admin);
        vault.skim(token, to);

        assertEq(token.balanceOf(to), amount);
    }

    function testSetRevertIfNotAuth() public {
        vm.expectRevert("Access denied");
        vault.set(asset);
    }

    function testMintRevertIfNotAuth() public {
        vm.expectRevert("Access denied");
        vault.mint(address(0), 0);
    }

    function testSkimRevertIfNotAuth() public {
        vm.expectRevert("Access denied");
        vault.skim(asset, address(0));
    }

    function testTotalAssetsIfNotSet() public {
        assertEq(vault.totalAssets(), 0);
    }
}

abstract contract WithAsset is Deployed {
    function setUp() public override virtual {
        super.setUp();

        vm.prank(admin);
        vault.set(asset);
    }
}

contract WithAssetTest is WithAsset {
    function testConvertToSharesIfZero() public {
        assertEq(vault.convertToShares(0), 0);
    }

    function testConvertToAssetsIfZero() public {
        assertEq(vault.convertToAssets(0), 0);
    }

    function testSkimRevertForAsset() public {
        vm.expectRevert("Cannot skim asset");
        vm.prank(admin);
        vault.skim(asset, address(0));
    }
}

abstract contract WithFunds is WithAsset {
    function setUp() public override virtual {
        super.setUp();

        uint assetAmount = 100 * assetUnit;
        cash(asset, address(vault), assetAmount);
    }
}

contract WithFundsTest is WithFunds {

    function testConvertToSharesIfNotMinted() public {
        assertEq(vault.convertToShares(0), 0);
    }

    function testConvertToAssetsIfNotMinted() public {
        assertEq(vault.convertToAssets(0), 0);
    }

    function testSetAgain() public {
        ERC20 token = ERC20(address(new ERC20Mock("Other Token", "OTH")));
        vm.expectEmit(true, false, false, false);
        emit AssetSet(token);

        vm.prank(admin);
        vault.set(token);

        assertEq(address(vault.asset()), address(token));
    }

    function testMint() public {
        uint assetAmount = asset.balanceOf(address(vault));
        uint sharesAmount = assetAmount / assetUnit;

        vm.prank(admin);
        vault.mint(user, sharesAmount);

        assertEq(vault.balanceOf(user), sharesAmount);
        assertEq(vault.totalSupply(), sharesAmount);
    }
}

abstract contract Minted is WithFunds {
    function setUp() public override virtual {
        super.setUp();

        uint assetAmount = asset.balanceOf(address(vault));
        uint sharesAmount = assetAmount / assetUnit;

        vm.prank(admin);
        vault.mint(user, sharesAmount);
    }
}

contract MintedTest is Minted {

    function testConvertToShares() public {
        uint assetAmount = asset.balanceOf(address(vault));
        uint sharesAmount = assetAmount / assetUnit;

        assertEq(vault.convertToShares(assetAmount), sharesAmount);
    }

    function testConvertToAssets() public {
        uint assetAmount = asset.balanceOf(address(vault));
        uint sharesAmount = assetAmount / assetUnit;

        assertEq(vault.convertToAssets(sharesAmount), assetAmount);
    }

    function testMintAgain() public {
        uint totalSupply = vault.totalSupply();
        uint assetAmount = asset.balanceOf(address(vault));
        uint sharesAmount = assetAmount / assetUnit;

        vm.prank(admin);
        vault.mint(other, sharesAmount);

        assertEq(vault.balanceOf(other), sharesAmount);
        assertEq(vault.totalSupply(), totalSupply + sharesAmount);
    }

    function testTransfer() public {
        uint totalSupply = vault.totalSupply();
        uint assetAmount = asset.balanceOf(address(vault));

        uint sharesAmount = vault.balanceOf(user);
        vm.prank(user);
        vault.transfer(other, sharesAmount);

        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.totalSupply(), totalSupply - sharesAmount);
        assertEq(asset.balanceOf(other), sharesAmount * assetAmount / totalSupply);
    }
}