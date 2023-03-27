// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/utils/Timelock.sol";
import { Assert } from "../src/utils/Assert.sol";
import { ERC20Mock } from "../src/mocks/ERC20Mock.sol";
import { TestExtensions } from "./utils/TestExtensions.sol";
import { TestConstants } from "./utils/TestConstants.sol";


using stdStorage for StdStorage;

abstract contract Deployed is Test, TestExtensions, TestConstants {

    Assert public assertContract;
    ERC20Mock public target;

    function setUp() public virtual {
        assertContract = new Assert();
        target = new ERC20Mock("Test", "TST");
        target.mint(address(this), 1000);
        target.mint(address(target), 1000);

        vm.label(address(target), "target");
    }
}

contract DeployedTest is Deployed {

    function testTwoEqualValues() public view {
        assertContract.assertEq(1, 1);
    }

    function testTwoUnequalValues() public {
        vm.expectRevert("Not equal to expected");
        assertContract.assertEq(1, 2);

        vm.expectRevert("Not equal");
        assertContract.assertEq(1, 2, "Not equal");
    }

    function testTwoEqualCalls() public {
        bytes memory actualCalldata = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        bytes memory expectedCalldata = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        assertContract.assertEq(address(target), actualCalldata, address(target), expectedCalldata);
    }

    function testTwoUnequalCalls() public {
        bytes memory actualCalldata = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        bytes memory expectedCalldata = abi.encodeWithSelector(target.balanceOf.selector, address(target));
        vm.expectRevert("Not equal to expected");
        assertContract.assertEq(address(target), actualCalldata, address(target), expectedCalldata);

        vm.expectRevert("Not equal");
        assertContract.assertEq(address(target), actualCalldata, address(target), expectedCalldata, "Not equal");
    }

    function testCallAndValue() public {
        bytes memory actualCalldata = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        uint actual = target.totalSupply();
        assertContract.assertEq(address(target), actualCalldata, actual);
    }

    function testUnequalCallAndValue() public {
        bytes memory actualCalldata = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        uint actual = target.balanceOf(address(target));
        vm.expectRevert("Not equal to expected");
        assertContract.assertEq(address(target), actualCalldata, actual);

        vm.expectRevert("Not equal");
        assertContract.assertEq(address(target), actualCalldata, actual, "Not equal");
    }

    function testEqAbs() public {
        assertContract.assertEqAbs(2, 1, 1);

        vm.expectRevert("Not within expected range");
        assertContract.assertEqAbs(3, 1, 1);

        vm.expectRevert("Not within expected range");
        assertContract.assertEqAbs(1, 3, 1);

        vm.expectRevert("Not within expected range");
        assertContract.assertEqAbs(3, 1, 1, "Not within expected range");

        vm.expectRevert("Not within expected range");
        assertContract.assertEqAbs(1, 3, 1, "Not within expected range");


        assertContract.assertEqAbs(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1500,
            500
        );

        assertContract.assertEqAbs(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            1000
        );
    }


    function testEqRel() public {
        assertContract.assertEqRel(2200, 2000, 1e17);

        vm.expectRevert("Not within expected range");
        assertContract.assertEqRel(2201, 2000, 1e17);

        vm.expectRevert("Not within expected range");
        assertContract.assertEqRel(1799, 2000, 1e17);

        vm.expectRevert("Not within expected range");
        assertContract.assertEqRel(2201, 2000, 1e17, "Not within expected range");

        vm.expectRevert("Not within expected range");
        assertContract.assertEqRel(1799, 2000, 1e17, "Not within expected range");

        assertContract.assertEqRel(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1100,
            1e17
        );

        assertContract.assertEqRel(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            1e18
        );
    }

    function testGreaterThan() public {
        assertContract.assertGt(2, 1);
        
        assertContract.assertGt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1
        );

        assertContract.assertGt(
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target))
        );

        vm.expectRevert("Not greater than expected");
        assertContract.assertGt(1, 2);

        vm.expectRevert("Not greater than expected");
        assertContract.assertGt(1, 2, "Not greater than expected");

        vm.expectRevert("Not greater than expected");
        assertContract.assertGt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            2000
        );

        vm.expectRevert("Not greater than expected");
        assertContract.assertGt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target), "Not greater than expected"),
            2000
        );

        vm.expectRevert("Not greater than expected");
        assertContract.assertGt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target))
        );

        vm.expectRevert("Not greater than expected");
        assertContract.assertGt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            "Not greater than expected"
        );
    }

    function testLessThan() public {
        assertContract.assertLt(1, 2);

        assertContract.assertLt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            2000
        );
        
        assertContract.assertLt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target))
        );

        vm.expectRevert("Not less than expected");
        assertContract.assertLt(2, 1);

        vm.expectRevert("Not less than expected");
        assertContract.assertLt(2, 1, "Not less than expected");

        vm.expectRevert("Not less than expected");
        assertContract.assertLt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1000
        );
         
        vm.expectRevert("Not less than expected");
        assertContract.assertLt(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1000,
            "Not less than expected"
        );

        vm.expectRevert("Not less than expected");
        assertContract.assertLt(
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target))
        );

        vm.expectRevert("Not less than expected");
        assertContract.assertLt(
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            "Not less than expected"
        );
    }

    function testGreaterThanOrEqual() public {
        assertContract.assertGe(2, 1);

        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1
        );
        
        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target))
        );

        assertContract.assertGe(2, 2);

        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1000
        );
        
        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target))
        );

        vm.expectRevert("Not greater or equal to expected");
        assertContract.assertGe(1, 2);

        vm.expectRevert("Not greater or equal to expected");
        assertContract.assertGe(1, 2, "Not greater or equal to expected");

        vm.expectRevert("Not greater or equal to expected");
        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            2000
        );

        vm.expectRevert("Not greater or equal to expected");
        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            2000,
            "Not greater or equal to expected"
        );
        
        vm.expectRevert("Not greater or equal to expected");
        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target))
        );

        vm.expectRevert("Not greater or equal to expected");
        assertContract.assertGe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            "Not greater or equal to expected"
        );
    }

    function testLessThanOrEqual() public {
        assertContract.assertLe(1, 2);

        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            2000
        );
        
        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target))
        );

        assertContract.assertLe(2, 2);
        
        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1000
        );
        
        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target))
        );

        vm.expectRevert("Not less or equal to expected");
        assertContract.assertLe(2, 1);

        vm.expectRevert("Not less or equal to expected");
        assertContract.assertLe(2, 1, "Not less or equal to expected");

        vm.expectRevert("Not less or equal to expected");
        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1
        );

        vm.expectRevert("Not less or equal to expected");
        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            1,
            "Not less or equal to expected"
        );

        vm.expectRevert("Not less or equal to expected");
        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target))
        );

        vm.expectRevert("Not less or equal to expected");
        assertContract.assertLe(
            address(target),
            abi.encodeWithSelector(target.totalSupply.selector, address(target)),
            address(target),
            abi.encodeWithSelector(target.balanceOf.selector, address(target)),
            "Not less or equal to expected"
        );
    }
}