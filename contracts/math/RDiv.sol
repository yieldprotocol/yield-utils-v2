// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


library RDiv { // Fixed point arithmetic for ray (27 decimal units)
    /// @dev Divide an amount by a fixed point factor with 27 decimals
    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = (x * 1e27) / y;
    }
}