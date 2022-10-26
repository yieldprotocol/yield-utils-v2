// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../../contracts/utils/EmergencyBrake.sol";
import "../../contracts/mocks/RestrictedERC20Mock.sol";
import "../../contracts/utils/Timelock.sol";

abstract contract ZeroState is Test {
    EmergencyBrake public ebrake;
    RestrictedERC20Mock public rToken;
    Timelock public lock;
    address public deployer;
    address public planner;
    address public executor;
    address public tokenAdmin;

    event Added(address indexed user, IEmergencyBrake.Permission permissionIn);
    event Removed(address indexed user, IEmergencyBrake.Permission permissionOut);
    event Executed(address indexed user);
    event Restored(address indexed user);

    bytes4 public constant ROOT = bytes4(0);

    IEmergencyBrake.Plan public plan;
    IEmergencyBrake.Permission[] public permissionsIn;
    IEmergencyBrake.Permission[] public permissionsOut;

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

    function testAddOne() public {
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;

        EmergencyBrake.Permission memory permissionIn = IEmergencyBrake.Permission(address(rToken), minterRole);

        vm.expectEmit(true, false, false, true);
        emit Added(tokenAdmin, permissionIn);

        permissionsIn.push(permissionIn);
        vm.prank(planner);
        ebrake.add(tokenAdmin, permissionsIn);

        assertFalse(ebrake.executed(tokenAdmin));
        assertTrue(ebrake.contains(tokenAdmin, permissionIn));
        assertEq(ebrake.index(tokenAdmin, permissionIn), 1);
        assertEq(ebrake.total(tokenAdmin), 1);

        permissionsIn.pop();
    }

    // testAddSeveral
    function testAddSeveral() public {
        permissionsIn.push(IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.mint.selector));
        permissionsIn.push(IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.burn.selector));

        vm.prank(planner);
        ebrake.add(tokenAdmin, permissionsIn);

        assertFalse(ebrake.executed(tokenAdmin));
        assertTrue(ebrake.contains(tokenAdmin, permissionsIn[0]));
        assertTrue(ebrake.contains(tokenAdmin, permissionsIn[1]));
        assertEq(ebrake.index(tokenAdmin, permissionsIn[0]), 1);
        assertEq(ebrake.index(tokenAdmin, permissionsIn[1]), 2);
        assertEq(ebrake.total(tokenAdmin), 2);

        permissionsIn.pop();
        permissionsIn.pop();
    }

    // testNotAddRoot
    function testNotAddRoot() public {
        permissionsIn.push(IEmergencyBrake.Permission(address(rToken), ROOT));

        vm.expectRevert("Can't remove ROOT");
        vm.prank(planner);
        ebrake.add(tokenAdmin, permissionsIn);

        permissionsIn.pop();
    }

    // testNotRemove
    function testNotRemove() public {
        permissionsOut.push(IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.mint.selector));

        vm.expectRevert("Permission not found");
        vm.prank(planner);
        ebrake.remove(tokenAdmin, permissionsOut);
        
        permissionsOut.pop();
    }

    // testNotExecute
    function testNotExecute() public {
        vm.expectRevert("Plan not found");
        vm.prank(executor);
        ebrake.execute(tokenAdmin);
    }

    // testNotTerminate
    function testNotTerminate() public {
        vm.expectRevert("Plan not found");
        vm.prank(planner);
        ebrake.terminate(tokenAdmin);
    }

    // testPermissionToId
    // testIdToPermission

}

/// @dev In this state we have a valid plan
abstract contract PlanState is ZeroState {

    function setUp() public virtual override {
        super.setUp();

        permissionsIn.push(IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.mint.selector));
        permissionsIn.push(IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.burn.selector));

        vm.prank(planner);
        ebrake.add(tokenAdmin, permissionsIn);

        permissionsIn.pop();
        permissionsIn.pop();
    }
}

contract PlanStateTest is PlanState {
    // testRemoveOne
    function testRemoveOne() public {
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;

        EmergencyBrake.Permission memory permissionOut = IEmergencyBrake.Permission(address(rToken), minterRole);

        vm.expectEmit(true, false, false, true);
        emit Removed(tokenAdmin, permissionOut);

        permissionsOut.push(permissionOut);
        vm.prank(planner);
        ebrake.remove(tokenAdmin, permissionsOut);

        assertFalse(ebrake.contains(tokenAdmin, permissionOut));
        assertEq(ebrake.index(tokenAdmin, permissionOut), 0);
        assertEq(ebrake.index(tokenAdmin, IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.burn.selector)), 1);
        assertEq(ebrake.total(tokenAdmin), 1);

        permissionsOut.pop();
    }

    // testRemoveSeveral
    function testRemoveSeveral() public {
        assertEq(ebrake.total(tokenAdmin), 2);

        permissionsOut.push(IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.mint.selector));
        permissionsOut.push(IEmergencyBrake.Permission(address(rToken), RestrictedERC20Mock.burn.selector));
        vm.prank(planner);
        ebrake.remove(tokenAdmin, permissionsOut);

        assertFalse(ebrake.contains(tokenAdmin, permissionsOut[0]));
        assertFalse(ebrake.contains(tokenAdmin, permissionsOut[1]));
        assertEq(ebrake.index(tokenAdmin, permissionsOut[0]), 0);
        assertEq(ebrake.index(tokenAdmin, permissionsOut[1]), 0);
        assertEq(ebrake.total(tokenAdmin), 0);

        permissionsOut.pop();
        permissionsOut.pop();
    }

    // testRemoveNotFound
    function testRemoveNotFound() public {
        permissionsOut.push(IEmergencyBrake.Permission(address(rToken), ERC20.transfer.selector));

        vm.expectRevert("Permission not found");
        vm.prank(planner);
        ebrake.remove(tokenAdmin, permissionsOut);
        
        permissionsOut.pop();
    }

    // testExecute
    function testExecute() public {
        vm.expectEmit(true, false, false, true);
        emit Executed(tokenAdmin);
        vm.prank(executor);
        ebrake.execute(tokenAdmin);

        assertTrue(ebrake.executed(tokenAdmin));

        vm.expectRevert("Access denied");
        vm.prank(tokenAdmin);
        rToken.mint(deployer, 1e18);

        vm.expectRevert("Access denied");
        vm.prank(tokenAdmin);
        rToken.burn(deployer, 1e18);
    }

    // testExecuteNotHasRole
//    function testExecuteNotHasRole() public {
//        vm.prank(deployer);
//        rToken.revokeRole(RestrictedERC20Mock.mint.selector, tokenAdmin);
//
//        vm.expectRevert("Permission not found");
//        vm.prank(executor);
//        ebrake.execute(tokenAdmin);
//    }

    // testEraseNotFound
    function testEraseNotFound() public {
       vm.expectRevert("Plan not found");
       vm.prank(executor);
       ebrake.execute(executor);
    }

    // testCancel
    function testCancel() public {
        permissionsOut.push(ebrake.permissionAt(tokenAdmin, 0));
        permissionsOut.push(ebrake.permissionAt(tokenAdmin, 1));

        vm.prank(planner);
        ebrake.cancel(tokenAdmin);

        assertFalse(ebrake.contains(tokenAdmin, permissionsOut[0]));
        assertFalse(ebrake.contains(tokenAdmin, permissionsOut[1]));
        assertEq(ebrake.index(tokenAdmin, permissionsOut[0]), 0);
        assertEq(ebrake.index(tokenAdmin, permissionsOut[1]), 0);
        assertEq(ebrake.total(tokenAdmin), 0);
    }

    // testTerminateNotExecuted
    function testTerminateAnytime() public {
        permissionsOut.push(ebrake.permissionAt(tokenAdmin, 0));
        permissionsOut.push(ebrake.permissionAt(tokenAdmin, 1));

        vm.prank(planner);
        ebrake.terminate(tokenAdmin);

        assertFalse(ebrake.contains(tokenAdmin, permissionsOut[0]));
        assertFalse(ebrake.contains(tokenAdmin, permissionsOut[1]));
        assertEq(ebrake.index(tokenAdmin, permissionsOut[0]), 0);
        assertEq(ebrake.index(tokenAdmin, permissionsOut[1]), 0);
        assertEq(ebrake.total(tokenAdmin), 0);
    }
}

/// @dev In this state we have an executed plan
abstract contract ExecuteState is PlanState {

    function setUp() public virtual override {
        super.setUp();
    }

    // testAddExecuted
    // testRemoveExecuted
    // testCancelExecuted
    // testExecuteExecuted
    // testRestoreNotFound

    // testNotRestore
    // function testNotRestore() public {
    //     vm.expectRevert("Plan not found");
    //     vm.prank(planner);
    //     ebrake.restore(tokenAdmin);
    // }

    // testRestore
    // testTerminateExecuted
}
// 
// abstract contract PlanState is ZeroState {
// 
//     function setUp() public virtual override {
//         super.setUp();
//         
//         bytes4 minterRole = RestrictedERC20Mock.mint.selector;
//         bytes4 burnerRole = RestrictedERC20Mock.burn.selector;
// 
//         permissions.push(IEmergencyBrake.Permission(address(rToken), minterRole));
//         permissions.push(IEmergencyBrake.Permission(address(rToken), burnerRole));
// 
//         vm.startPrank(planner);
//         ebrake.plan(tokenAdmin, permissions);
//         ebrake.plan(executor, permissions);
//         vm.stopPrank();
//         delete permissions;
//     }
// }
// 
// contract PlanStateTest is PlanState {
// 
//     function testCancel() public {
//         vm.prank(planner);
//         vm.expectEmit(true, false, false, true);
//         emit Cancelled(tokenAdmin);
//         ebrake.cancel(tokenAdmin);
//         
//         (EmergencyBrake.State state_
//         ) = ebrake.plans(tokenAdmin);
// 
//        bool isCancelled = EmergencyBrake.State.UNPLANNED == state_;
//        assertEq(isCancelled, true);
//     }
// 
//     function testExecute() public {
//         vm.expectEmit(true, false, false, true);
//         emit Executed(tokenAdmin);
//         vm.prank(executor);
//         ebrake.execute(tokenAdmin);
// 
//         (EmergencyBrake.State state_
//             
//         ) = ebrake.plans(tokenAdmin);
//         
//         bool isExecuted = EmergencyBrake.State.EXECUTED == state_;
//         assertEq(isExecuted, true);
// 
//         vm.expectRevert("Access denied");
//         vm.prank(tokenAdmin);
//         rToken.mint(deployer, 1e18);
//     }
// 
//     function testCannotExecuteGhostRoles() public {
//         vm.expectRevert("Permission not found");
//         vm.prank(executor);
//         ebrake.execute(executor);
//     }
// 
//     function testAddToPlan() public {
//         bytes4 propose = Timelock.propose.selector;
//         
//         permission = IEmergencyBrake.Permission(address(lock), propose);
//         
//         vm.expectEmit(true, false, false, true);
//         emit PermissionAdded(tokenAdmin, permission);
//         vm.prank(planner);
//         ebrake.addToPlan(tokenAdmin, permission);
//     }
// 
//     function testRemoveFromPlan() public {
//         bytes4 minterRole = RestrictedERC20Mock.mint.selector;
// 
//         permission = IEmergencyBrake.Permission(address(rToken), minterRole);
// 
//         vm.expectEmit(true, false, false, true);
//         emit PermissionRemoved(tokenAdmin, permission);
//         vm.prank(planner);
//         ebrake.removeFromPlan(tokenAdmin, permission);
//     }
// 
//     function testCannotAddDuplicateSignature() public {
//         bytes4 minterRole = RestrictedERC20Mock.mint.selector;
// 
//         permission = IEmergencyBrake.Permission(address(rToken), minterRole);
// 
//         vm.expectRevert("Permission set already in plan");
//         vm.prank(planner);
//         ebrake.addToPlan(tokenAdmin, permission);
//     }
// 
//     function testCannotAddRoot() public {
//         permission = IEmergencyBrake.Permission(address(rToken), ROOT);
// 
//         vm.expectRevert("Can't remove ROOT");
//         vm.prank(planner);
//         ebrake.addToPlan(tokenAdmin, permission);
//     }
// 
//     function testCannotRemoveUnplannedPermission() public {
//         bytes4 propose = Timelock.propose.selector;
// 
//         permission = IEmergencyBrake.Permission(address(lock), propose);
// 
//         vm.expectRevert("Permission set not planned");
//         vm.prank(planner);
//         ebrake.removeFromPlan(tokenAdmin, permission); 
//     }
// }
// 
// abstract contract ExecutedState is PlanState {
// 
//     function setUp() public virtual override {
//         super.setUp();
//         vm.prank(executor);
//         ebrake.execute(tokenAdmin);
//     }
// }
// 
// contract ExecutedStateTest is ExecutedState {
//      
//     function testRestore() public {
//         vm.expectEmit(true, false, false, true);
//         emit Restored(tokenAdmin);
//         vm.prank(planner);
//         ebrake.restore(tokenAdmin);
// 
//         (EmergencyBrake.State state_
//             
//         ) = ebrake.plans(tokenAdmin);
// 
//         bool isPlanned = EmergencyBrake.State.PLANNED == state_;
//         assertEq(isPlanned, true);
//     }
// 
//     function testTerminate() public {
//         vm.expectEmit(true, false, false, true);
//         emit Terminated(tokenAdmin);
//         vm.prank(planner);
//         ebrake.terminate(tokenAdmin);
// 
//         (EmergencyBrake.State state_ ) = ebrake.plans(tokenAdmin);
// 
//         bool isUnplanned = EmergencyBrake.State.UNPLANNED == state_;
//         assertEq(isUnplanned, true);
//     }
// }