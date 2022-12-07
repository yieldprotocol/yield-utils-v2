// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../contracts/utils/Timelock.sol";
import { OnChainTest } from "../contracts/utils/OnChainTest.sol";
import { ERC20Mock } from "../contracts/mocks/ERC20Mock.sol";
import { TestExtensions } from "./utils/TestExtensions.sol";
import { TestConstants } from "./utils/TestConstants.sol";


using stdStorage for StdStorage;

abstract contract Deployed is Test, TestExtensions, TestConstants {

    OnChainTest public onChainTest;
    ERC20Mock public target;

    function setUpMock() public {
        onChainTest = new OnChainTest();
        target = new ERC20Mock("Test", "TST");
        target.mint(address(this), 1000);
    }

    function setUpHarness(string memory network) public {
        setUpMock(); // TODO: Think about a test harness.
    }

    function setUp() public virtual {
        string memory network = vm.envString(NETWORK);
        if (!equal(network, LOCALHOST)) vm.createSelectFork(network);

        if (vm.envBool(MOCK)) setUpMock();
        else setUpHarness(network);

        vm.label(address(target), "target");
    }
}

contract DeployedTest is Deployed {

    function testTwoEqualValues() public {
        bytes memory value1 = abi.encodePacked(uint256(1));
        bytes memory value2 = abi.encodePacked(uint256(1));
        onChainTest.twoValuesEquator(value1, value2);
    }

    function testTwoUnequalValues() public {
        bytes memory value1 = abi.encodePacked(uint256(1));
        bytes memory value2 = abi.encodePacked(uint256(2));
        vm.expectRevert("Mismatched value");
        onChainTest.twoValuesEquator(value1, value2);
    }

    function testTwoEqualCalls() public {
        bytes memory call1 = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        bytes memory call2 = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        onChainTest.twoCallsEquator(address(target), address(target), call1, call2);
    }

    function testTwoUnequalCalls() public {
        bytes memory call1 = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        bytes memory call2 = abi.encodeWithSelector(target.balanceOf.selector, address(target));
        vm.expectRevert("Mismatched value");
        onChainTest.twoCallsEquator(address(target), address(target), call1, call2);
    }

    function testCallAndValue() public {
        bytes memory call1 = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        bytes memory value1 = abi.encodePacked(target.totalSupply());
        onChainTest.valueAndCallEquator(address(target), call1, value1);
    }

    function testUnequalCallAndValue() public {
        bytes memory call1 = abi.encodeWithSelector(target.totalSupply.selector, address(target));
        bytes memory value1 = abi.encodePacked(target.balanceOf(address(target)));
        vm.expectRevert("Mismatched value");
        onChainTest.valueAndCallEquator(address(target), call1, value1);
    }
}