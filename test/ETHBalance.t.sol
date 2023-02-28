// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/token/ETHBalance.sol";
import { TestExtensions } from "./utils/TestExtensions.sol";
import { TestConstants } from "./utils/TestConstants.sol";


using stdStorage for StdStorage;

abstract contract Deployed is Test, TestExtensions, TestConstants {
    ETHBalance public ethBalance;

    function setUp() public virtual {
        ethBalance = new ETHBalance();
    }
}

contract DeployedTest is Deployed {

    function testGetBalance() public {
        vm.deal(address(this), 1);
        assertEq(ethBalance.getBalance(address(this)), 1);
    }

    function testFuzzGetBalance(uint256 balance, address user) public {
        vm.deal(user, balance);
        assertEq(ethBalance.getBalance(user), balance);
    }
}
