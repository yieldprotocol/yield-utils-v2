// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./WMul.sol";

library WPow {
    // Taken from https://github.com/Rari-Capital/solmate/blob/main/src/utils/FixedPointMathLib.sol
    /// @dev $x ^ $n; $x is 18-decimals fixed point number
    function wpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        uint256 baseUnit = 1e18;
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    z := baseUnit
                }
                default {
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    z := baseUnit
                }
                default {
                    z := x
                }
                let half := div(baseUnit, 2)
                for {
                    n := div(n, 2)
                } n {
                    n := div(n, 2)
                } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) {
                        revert(0, 0)
                    }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }
                    x := div(xxRound, baseUnit)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                            revert(0, 0)
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }
                        z := div(zxRound, baseUnit)
                    }
                }
            }
        }
    }
}
