// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../../contracts/utils/EmergencyBrakeV2a.sol";
import "../../contracts/mocks/RestrictedERC20Mock.sol";

abstract contract ZeroState is Test {
    enum State {UNPLANNED, PLANNED, EXECUTED}
    EmergencyBrakeV2 public ebrake;
    RestrictedERC20Mock public rToken;
    address public deployer;
    address public planner;
    address public executor;
    address public tokenAdmin;

    event Planned(address indexed target);
    event Modified(address indexed target);
    event Cancelled(address indexed target);
    event Executed(address indexed target);
    event Restored(address indexed target);
    event Terminated(address indexed target);

    bytes4 public constant ROOT = 0x00000000;

    bytes4[] public signatures;
    IEmergencyBrake.Permission[] public permissions;

    function setUp() public virtual {
        vm.startPrank(deployer);

        deployer = address(1);
        vm.label(deployer, "deployer");

        planner = address(2);
        vm.label(planner, "planner");

        executor = address(3);
        vm.label(executor, "executor");

        tokenAdmin = address(4);
        vm.label(tokenAdmin, "tokenAdmin");

        ebrake = new EmergencyBrakeV2(planner, executor);
        vm.label(address(ebrake), "Emergency Brake contract");

        rToken = new RestrictedERC20Mock("FakeToken", "FT");
        vm.label(address(rToken), "Restricted Token contract");

        rToken.grantRole(RestrictedERC20Mock.mint.selector, tokenAdmin);
        rToken.grantRole(RestrictedERC20Mock.burn.selector, tokenAdmin);
        rToken.grantRole(ROOT, address(ebrake));

        vm.stopPrank();
    }
}

contract ZeroStateTest is ZeroState {
     
    function testRoles(uint256 amount) public {
        uint256 preBalance = rToken.balanceOf(deployer);

        console2.log("Ensure that roles are set properly and functioning");
        console2.log("Minter can mint");
        
        vm.prank(tokenAdmin);
        rToken.mint(deployer, amount);
        assertEq(rToken.balanceOf(deployer), preBalance + amount);

        console2.log("Burner can burn");
        vm.prank(tokenAdmin);
        rToken.burn(deployer, amount);
        assertEq(rToken.balanceOf(deployer), preBalance);
    }

    function testCannotWithoutRole() public {
        vm.startPrank(planner);
        vm.expectRevert("Access denied");
        rToken.mint(deployer, 10000000);
        vm.expectRevert("Access denied");
        rToken.burn(deployer, 10000000);
        vm.stopPrank();
    }


    function testPlan() public {
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        signatures.push(minterRole);
        signatures.push(burnerRole);

        IEmergencyBrake.Permission memory permission_ = IEmergencyBrake.Permission(address(rToken), signatures);

        permissions.push(permission_);

        vm.expectEmit(true, false, false, true);
        emit Planned(tokenAdmin);
        vm.prank(planner);
        ebrake.plan(tokenAdmin, permissions);

        (EmergencyBrakeV2.State state_,
            ,
        ) = ebrake.plans(tokenAdmin);

       bool isPlanned = EmergencyBrakeV2.State.PLANNED == state_;
       assertEq(isPlanned, true);
    }

    function testCannotModifyUnplanned() public {
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        signatures.push(burnerRole);

        IEmergencyBrake.Permission memory permission_ = IEmergencyBrake.Permission(address(rToken), signatures);

        permissions.push(permission_);

        vm.expectRevert("Emergency not planned for.");
        vm.prank(planner);
        ebrake.modifyPlan(tokenAdmin, permissions);   
    }

    function testCannotCancelUnplanned() public {
        vm.expectRevert("Emergency not planned for.");
        vm.prank(planner);
        ebrake.cancel(tokenAdmin);
    }

    function testCannotExecuteUnplanned() public {
        vm.expectRevert("Emergency not planned for.");
        vm.prank(executor);
        ebrake.execute(tokenAdmin);
    }

    function testCannotRestoreUnexecuted() public {
        vm.expectRevert("Emergency plan not executed.");
        vm.prank(planner);
        ebrake.restore(tokenAdmin);
    }

    function testCannotTerminateUnexecuted() public {
        vm.expectRevert("Emergency plan not executed.");
        vm.prank(planner);
        ebrake.terminate(tokenAdmin);
    }
}

abstract contract PlanState is ZeroState {

    function setUp() public virtual override {
        super.setUp();
        
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        signatures.push(minterRole);
        signatures.push(burnerRole);

        IEmergencyBrake.Permission memory permission_ = IEmergencyBrake.Permission(address(rToken), signatures);

        permissions.push(permission_);

        vm.prank(planner);
        ebrake.plan(tokenAdmin, permissions);
    
    }
}

contract PlanStateTest is PlanState {

    function testCancel() public {
        vm.prank(planner);
        vm.expectEmit(true, false, false, true);
        emit Cancelled(tokenAdmin);
        ebrake.cancel(tokenAdmin);
        
        (EmergencyBrakeV2.State state_,
            ,
        ) = ebrake.plans(tokenAdmin);

       bool isCancelled = EmergencyBrakeV2.State.UNPLANNED == state_;
       assertEq(isCancelled, true);
    }

    function testExecute() public {
        vm.expectEmit(true, false, false, true);
        emit Executed(tokenAdmin);
        vm.prank(executor);
        ebrake.execute(tokenAdmin);

        (EmergencyBrakeV2.State state_,
            ,
        ) = ebrake.plans(tokenAdmin);
        
        bool isExecuted = EmergencyBrakeV2.State.EXECUTED == state_;
        assertEq(isExecuted, true);

        vm.expectRevert("Access denied");
        vm.prank(tokenAdmin);
        rToken.mint(deployer, 1e18);
    }

    function testModify() public {
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        signatures.push(burnerRole);

        IEmergencyBrake.Permission memory permission_ = IEmergencyBrake.Permission(address(rToken), signatures);

        permissions.push(permission_);

        vm.expectEmit(true, false, false, true);
        emit Modified(tokenAdmin);
        vm.prank(planner);
        ebrake.modifyPlan(tokenAdmin, permissions);
    }
}

abstract contract ExecutedState is PlanState {

    function setUp() public virtual override {
        super.setUp();
        vm.prank(executor);
        ebrake.execute(tokenAdmin);
    }
}

contract ExecutedStateTest is ExecutedState {
     
    function testRestore() public {

    }
}