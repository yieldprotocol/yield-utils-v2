// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/token/TransferHelper.sol";
import "../../contracts/token/IERC20.sol";

contract TransferHelperTest is Test {
    using TransferHelper for IERC20;

    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address other = address(123);

    function setUp() public {
        vm.createSelectFork("mainnet");

        deal(address(usdt), address(this), 1000);
    }

    function testSafeApprove() public {
        console.log("can successfully safe approve");
        usdt.safeApprove(other, 100);
    }
}
