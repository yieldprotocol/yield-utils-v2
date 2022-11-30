// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../../contracts/token/ERC20Rewards.sol";
import "../../contracts/token/IERC20.sol";
import { ERC20Mock } from "../../contracts/mocks/ERC20Mock.sol";
import { TestExtensions } from "./utils/TestExtensions.sol";
import { TestConstants } from "./utils/TestConstants.sol";


using stdStorage for StdStorage;

abstract contract Deployed is Test, TestExtensions, TestConstants {

    event RewardsTokenSet(IERC20 token);
    event RewardsSet(uint32 start, uint32 end, uint256 rate);
    event RewardsPerTokenUpdated(uint256 accumulated);
    event UserRewardsUpdated(address user, uint256 userRewards, uint256 paidRewardPerToken);
    event Claimed(address receiver, uint256 claimed);

    ERC20Rewards public vault;
    uint256 public vaultUnit;
    IERC20 public rewards;
    uint256 public rewardsUnit;
        
    address user;
    address other;
    address admin;
    address me;

    function setUpMock() public {
        admin = address(3);

        vault = new ERC20Rewards("Incentivized Vault", "VLT", 18);
        vaultUnit = 10 ** ERC20Mock(address(vault)).decimals();
        rewards = IERC20(address(new ERC20Mock("Rewards Token", "REW")));
        rewardsUnit = 10 ** ERC20Mock(address(rewards)).decimals();
        
        vault.grantRole(ERC20Rewards.setRewardsToken.selector, admin);
        vault.grantRole(ERC20Rewards.setRewards.selector, admin);
    }

    function setUpHarness(string memory network) public {
        setUpMock(); // TODO: Setup the test harness
    }

    function setUp() public virtual {
        string memory network = vm.envString(NETWORK);
        if (!equal(network, LOCALHOST)) vm.createSelectFork(network);

        if (vm.envBool(MOCK)) setUpMock();
        else setUpHarness(network);

        //... Users ...
        user = address(1);
        other = address(2);
        me = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

        vm.label(user, "user");
        vm.label(other, "other");
        vm.label(admin, "admin");
        vm.label(me, "me");
        vm.label(address(vault), "vault");
        vm.label(address(rewards), "rewards");
    }  
}

contract DeployedTest is Deployed {

    function testSetRewardsToken(IERC20 token) public {
        vm.expectEmit(true, false, false, false);
        emit RewardsTokenSet(token);

        vm.prank(admin);
        vault.setRewardsToken(token);

        assertEq(address(vault.rewardsToken()), address(token));
    }
}

abstract contract WithRewardsToken is Deployed {
    function setUp() public override virtual {
        super.setUp();

        vm.prank(admin);
        vault.setRewardsToken(rewards);
    }
}


contract WithRewardsTokenTest is WithRewardsToken {

    function testDontResetRewardsToken(address token) public {
        vm.expectRevert(bytes("Rewards token already set"));

        vm.prank(admin);
        vault.setRewardsToken(IERC20(token));
    }

    function testStartBeforeEnd(uint32 start, uint32 end) public {
        end = uint32(bound(end, block.timestamp, type(uint32).max - 1));
        start = uint32(bound(start, end + 1, type(uint32).max));
        vm.expectRevert(bytes("Incorrect input"));
        vm.prank(admin);
        vault.setRewards(start, end, 1);
    }

    function testSetRewards(uint32 start, uint32 end, uint96 rate) public {
        end = uint32(bound(end, block.timestamp + 1, type(uint32).max));
        start = uint32(bound(start, block.timestamp, end - 1));

        vm.expectEmit(true, false, false, false);
        emit RewardsSet(start, end, rate);

        vm.prank(admin);
        vault.setRewards(start, end, rate);
    }
}

abstract contract WithProgram is WithRewardsToken {
    function setUp() public override virtual {
        super.setUp();

        uint256 totalRewards = WAD;
        uint256 start = block.timestamp + 1000000;
        uint256 length = 2000000;
        uint256 end = start + length;
        uint256 rate = totalRewards * 1e18 / length;

        vm.startPrank(admin);
        vault.setRewardsToken(rewards);
        vault.setRewards(uint32(start), uint32(end), uint96(rate));
        vm.stopPrank();

        cash(rewards, address(vault), totalRewards); // Rewards to be distributed
        cash(IERC20(address(vault)), address(vault), 1); // So that total supply is not zero TODO: Why?
    }
}

abstract contract DuringProgram is WithProgram {
    function setUp() public override virtual {
        super.setUp();
        (uint256 start, uint256 end) = vault.rewardsPeriod();

        vm.warp((start + end) / 2);
    }
}

abstract contract AfterProgramEnd is WithProgram {
    function setUp() public override virtual {
        super.setUp();

        super.setUp();
        (, uint256 end) = vault.rewardsPeriod();

        vm.warp(end + 1);
    }
}