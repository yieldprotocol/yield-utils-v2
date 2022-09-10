// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../../contracts/utils/EmergencyBrake.sol";
import "../../contracts/mocks/RestrictedERC20Mock.sol";
import "../../contracts/utils/Timelock.sol";

abstract contract ZeroState is Test {
    enum State {UNPLANNED, PLANNED, EXECUTED}
    EmergencyBrake public ebrake;
    RestrictedERC20Mock public rToken;
    Timelock public lock;
    address public deployer;
    address public planner;
    address public executor;
    address public tokenAdmin;

    event Planned(address indexed target, IEmergencyBrake.Permission[] permissions);
    event AddedTo(address indexed target, IEmergencyBrake.Permission toAdd);
    event RemovedFrom(address indexed target, IEmergencyBrake.Permission toRemove);
    event Cancelled(address indexed target);
    event Executed(address indexed target);
    event Restored(address indexed target);
    event Terminated(address indexed target);

    bytes4 public constant ROOT = 0x00000000;

    bytes4[] public signatures;
    IEmergencyBrake.Permission[] public permissions;
    IEmergencyBrake.Permission public permission;

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

        ebrake = new EmergencyBrake(planner, executor);
        vm.label(address(ebrake), "Emergency Brake contract");

        rToken = new RestrictedERC20Mock("FakeToken", "FT");
        vm.label(address(rToken), "Restricted Token contract");

        lock = new Timelock(tokenAdmin, executor);
        vm.label(address(lock), "Authed TimeLock contract");

        rToken.grantRole(RestrictedERC20Mock.mint.selector, tokenAdmin);
        rToken.grantRole(RestrictedERC20Mock.burn.selector, tokenAdmin);
        rToken.grantRole(ROOT, address(ebrake));

        vm.stopPrank();
    }
}

contract ZeroStateTest is ZeroState {

    function testPlan() public {
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        signatures.push(minterRole);
        signatures.push(burnerRole);

        IEmergencyBrake.Permission memory permission_ = IEmergencyBrake.Permission(address(rToken), signatures);

        permissions.push(permission_);

        vm.expectEmit(true, false, false, true);
        emit Planned(tokenAdmin, permissions);
        vm.prank(planner);
        ebrake.plan(tokenAdmin, permissions);

        (EmergencyBrake.State state_,
            
        ) = ebrake.plans(tokenAdmin);

        bool isPlanned = EmergencyBrake.State.PLANNED == state_;
        assertEq(isPlanned, true);
    }

    function testCannotAddToUnplanned() public {
        vm.expectRevert("Target not planned for");
        vm.prank(planner);
        ebrake.addToPlan(tokenAdmin, permission);
    }

    function testCannotRemoveFromUnplanned() public {
        vm.expectRevert("Target not planned for");
        vm.prank(planner);
        ebrake.removeFromPlan(tokenAdmin, permission);
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

    function testCannotPlanRoot() public {
        signatures.push(ROOT);

        IEmergencyBrake.Permission memory permission_ = IEmergencyBrake.Permission(address(rToken), signatures);

        permissions.push(permission_);

        vm.expectRevert("Can't remove ROOT");
        vm.prank(planner);
        ebrake.plan(tokenAdmin, permissions);
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

        vm.startPrank(planner);
        ebrake.plan(tokenAdmin, permissions);
        ebrake.plan(executor, permissions);
        vm.stopPrank();
        delete signatures;
        delete permissions;
    }
}

contract PlanStateTest is PlanState {

    function testCancel() public {
        vm.prank(planner);
        vm.expectEmit(true, false, false, true);
        emit Cancelled(tokenAdmin);
        ebrake.cancel(tokenAdmin);
        
        (EmergencyBrake.State state_,
            
        ) = ebrake.plans(tokenAdmin);

       bool isCancelled = EmergencyBrake.State.UNPLANNED == state_;
       assertEq(isCancelled, true);
    }

    function testExecute() public {
        vm.expectEmit(true, false, false, true);
        emit Executed(tokenAdmin);
        vm.prank(executor);
        ebrake.execute(tokenAdmin);

        (EmergencyBrake.State state_,
            
        ) = ebrake.plans(tokenAdmin);
        
        bool isExecuted = EmergencyBrake.State.EXECUTED == state_;
        assertEq(isExecuted, true);

        vm.expectRevert("Access denied");
        vm.prank(tokenAdmin);
        rToken.mint(deployer, 1e18);
    }

    function testCannotExecuteGhostRoles() public {
        vm.expectRevert("Permission not found");
        vm.prank(executor);
        ebrake.execute(executor);
    }

    function testAddToPlan() public {
        bytes4 propose = Timelock.propose.selector;
        bytes4 approve = Timelock.approve.selector;
        bytes4 cancel = Timelock.cancel.selector;

        signatures.push(propose);
        signatures.push(approve);
        signatures.push(cancel);

        permission = IEmergencyBrake.Permission(address(lock), signatures);
        
        vm.expectEmit(true, false, false, true);
        emit AddedTo(tokenAdmin, permission);
        vm.prank(planner);
        ebrake.addToPlan(tokenAdmin, permission);
    }

    function testRemoveFromPlan() public {
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        signatures.push(minterRole);
        signatures.push(burnerRole);

        permission = IEmergencyBrake.Permission(address(rToken), signatures);

        vm.expectEmit(true, false, false, true);
        emit RemovedFrom(tokenAdmin, permission);
        vm.prank(planner);
        ebrake.removeFromPlan(tokenAdmin, permission);
    }

    function testCannotAddDuplicateSignature() public {
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        signatures.push(minterRole);
        signatures.push(burnerRole);

        permission = IEmergencyBrake.Permission(address(rToken), signatures);

        vm.expectRevert("Signature already in plan");
        vm.prank(planner);
        ebrake.addToPlan(tokenAdmin, permission);
    }

    function testCannotAddRoot() public {
        signatures.push(ROOT);

        permission = IEmergencyBrake.Permission(address(rToken), signatures);

        vm.expectRevert("Can't remove ROOT");
        vm.prank(planner);
        ebrake.addToPlan(tokenAdmin, permission);
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
        vm.expectEmit(true, false, false, true);
        emit Restored(tokenAdmin);
        vm.prank(planner);
        ebrake.restore(tokenAdmin);

        (EmergencyBrake.State state_,
            
        ) = ebrake.plans(tokenAdmin);

        bool isPlanned = EmergencyBrake.State.PLANNED == state_;
        assertEq(isPlanned, true);
    }

    function testTerminate() public {
        vm.expectEmit(true, false, false, true);
        emit Terminated(tokenAdmin);
        vm.prank(planner);
        ebrake.terminate(tokenAdmin);

        (EmergencyBrake.State state_, ) = ebrake.plans(tokenAdmin);

        bool isUnplanned = EmergencyBrake.State.UNPLANNED == state_;
        assertEq(isUnplanned, true);
    }
}