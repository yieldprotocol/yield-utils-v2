// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/token/TransferHelper.sol";
import "../../contracts/token/IERC20.sol";

interface IERC20Like {
    // mimic USDT approve functionality
    function approve(address spender, uint256 amount) external;
}

contract TransferHelperTest is Test {
    using TransferHelper for IERC20;

    IERC20Like usdtHelper = IERC20Like(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address other = address(123);

    function setUp() public {
        vm.createSelectFork("mainnet");

        deal(address(usdt), address(this), 100);
    }

    function testSafeApprove() public {
        console.log("can successfully safe approve");
        usdt.safeApprove(other, 100);
        assertEq(
            usdt.allowance(address(this), other), 
            100
        );
    }

    // function testRevertWithNonZeroAllowance() public {
    //     console.log("reverts on non zero allowance");
    //     usdtHelper.approve(other, 10);
    //     vm.expectRevert("approve from non-zero to non-zero allowance");
    //     usdt.safeApprove(other, 100);
    // }

    // function testRevertWithZeroValue() public {
    //     console.log("reverts on non zero allowance");
    //     usdtHelper.approve(other, 10);
    //     vm.expectRevert("approve from non-zero to non-zero allowance");
    //     usdt.safeApprove(other, 0);
    // }

    // function testRevertWithInsufficientBalance() public {
    //     console.log("reverts with insufficient balance");
    //     vm.deal(address(this), 0 ether);
    //     vm.expectRevert("insufficient balance for call");
    //     usdt.safeApprove(other, 1000);
    // }

    // function testRevertOnCallToNonContract() public {
    //     console.log("reverts when called on non contract");
    //     vm.expectRevert("call to non-contract");
    //     IERC20(address(456)).safeApprove(address(other), 1000);
    // }
}
