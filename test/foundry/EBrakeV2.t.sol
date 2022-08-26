// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../../contracts/utils/EmergencyBrakeV2.sol";
import "../../contracts/mocks/RestrictedERC20Mock.sol";

abstract contract ZeroState is Test {

    EmergencyBrakeV2 public ebrake;
    RestrictedERC20Mock public rToken;
    address public deployer;
    address public planner;
    address public executor;
    address public minter;
    address public burner;

    event Planned(address indexed target, string planName);
    event Cancelled(address indexed target, string planName);
    event Executed(address indexed target, string planName);
    event Restored(address indexed target, string planName);
    event Terminated(address indexed target, string planName);

    bytes4 public constant ROOT = 0x00000000;

    function setUp() public virtual {
        vm.startPrank(deployer);

        deployer = address(1);
        vm.label(deployer, "deployer");

        planner = address(2);
        vm.label(planner, "planner");

        executor = address(3);
        vm.label(executor, "executor");

        minter = address(4);
        vm.label(minter, "minter");

        burner = address(5);
        vm.label(burner, "burner");

        ebrake = new EmergencyBrakeV2(planner, executor);
        vm.label(address(ebrake), "Emergency Brake contract");

        rToken = new RestrictedERC20Mock("FakeToken", "FT");
        vm.label(address(rToken), "Restricted Token contract");

        rToken.grantRole(RestrictedERC20Mock.mint.selector, minter);
        rToken.grantRole(RestrictedERC20Mock.burn.selector, burner);
        rToken.grantRole(ROOT, address(ebrake));

        vm.stopPrank();
    }
}

contract ZeroStateTest is ZeroState {
     
     function testPlan() public {
        bytes4 minterRole = RestrictedERC20Mock.mint.selector;
        bytes4 burnerRole = RestrictedERC20Mock.burn.selector;

        bytes4[] memory mR;
        bytes4[] memory bR;

        mR[0] = minterRole;
        bR[0] = burnerRole;


        IEmergencyBrake.Permission memory minter_ = IEmergencyBrake.Permission(minter, mR);
        IEmergencyBrake.Permission memory burner_ = IEmergencyBrake.Permission(burner, bR);

        IEmergencyBrake.Permission[] memory permissions;

        permissions[0] = minter_;
        permissions[1] = burner_;

        vm.expectEmit(true, false, false, true);
        emit Planned(address(rToken), "testPlan");
        ebrake.plan(address(rToken), "testPlan", permissions);

     }
}