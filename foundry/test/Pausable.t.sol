// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "src/Pausable.sol";
import "test/DummyWand.sol";

abstract contract StateZero is Test {
    
    event PausedState(address indexed account, bool indexed state);

    Pausable public pausable;
    DummyWand public dummyWand;
    address deployer;

    function setUp() public virtual {
        vm.startPrank(deployer);

        deployer = address(1);
        vm.label(deployer, "deployer");

        pausable = new Pausable();
        vm.label(address(pausable), "Pausable contract");

        dummyWand = new DummyWand();
        vm.label(address(dummyWand), "DummmyWand contract");

        //... Granting permissions ...
        dummyWand.grantRole(DummyWand.actionWhenPaused.selector, deployer);
        dummyWand.grantRole(DummyWand.actionWhenNotPaused.selector, deployer);
        vm.stopPrank();
    }   
}

contract StateZeroTest is StateZero {

    function testNotPaused() public {
        console2.log("On deployment, _paused == false. Wand active.");
        vm.prank(deployer);

        vm.expectRevert("Pausable: not paused");
        dummyWand.actionWhenPaused();

        assertTrue(dummyWand.paused() == false);
    }

    function testActive() public {
        console2.log("On deployment, _paused == false. Contract active.");

        vm.prank(deployer);
        uint256 value = dummyWand.actionWhenNotPaused();

        assertTrue(value == 1);
        assertTrue(dummyWand.paused() == false);
    }

}

abstract contract StatePaused is StateZero {
    function setUp() public override virtual {
        super.setUp();

        vm.prank(deployer);
        dummyWand._unpause();
    }
}
