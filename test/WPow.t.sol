// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "./WPow.sol";

contract FixedPointMathLibTest is DSTest {
    // test a couple of concrete cases
    function testWPow() public {
        assertEq(WPow.wpow(2e18, 2), 4e18);
        assertEq(WPow.wpow(2e18, 4), 16e18);

        assertEq(WPow.wpow(0, 0), 1e18);
        assertEq(WPow.wpow(0, 1), 0);
        assertEq(WPow.wpow(0, 10), 0);

        assertEq(WPow.wpow(1, 0), 1e18);
        assertEq(WPow.wpow(1e18, 0), 1e18);
    }

    // helper method
    function testWPowImpl(uint256 x, uint256 n) internal {
        uint256 expected = 1e18;
        if (n > 0) {
            expected = x;
        }
        bool expectExpectedToIncrease = (x > 1e18);
        if (n > 1) {
            for (uint256 i = 1; i < n; ++i) {
                unchecked {
                    uint256 old_expected = expected;
                    expected = (expected * x) / 1e18;
                    // check for overflow if x > 1
                    if (expectExpectedToIncrease && expected < old_expected) {
                        return;
                    }
                    if (expected == old_expected) {
                        break;
                    }
                }
            }
        }
        uint256 result = WPow.wpow(x, n);
        uint256 distance = (result > expected)
            ? result - expected
            : expected - result;
        emit log_uint(x);
        emit log_uint(expected);
        emit log_uint(result);
        emit log_uint(distance);
        uint acceptable_distance = result / 1e15;
        // if x < 1e18, we're allowed to lose 1 wei of precision on each iteration
        if (acceptable_distance < n) {
            acceptable_distance = n;
        }
        assertLe(distance, acceptable_distance);
    }

    // pick a radom delta_x from [0, 2]
    // pick a randrom n between 0 and 1000
    // set x = 1 +/- delta_x
    // check that wpow(x, y) is roughly the same as manual x * x * ... * x (n times)
    // 'roughly the same': the diff is smaller than result * 1e-15
    function testWPowBetween0and2(uint64 delta_x, uint16 n) public {
        if (delta_x > 1e18) {
            return;
        }
        if (n > 1000) {
            return;
        }
        for (int256 sign = -1; sign <= 1; sign += 2) {
            uint256 x = 1e18;
            if (sign < 0) {
                x = x + delta_x;
            } else {
                x = x - delta_x;
            }
            testWPowImpl(x, n);
        }
    }
}
