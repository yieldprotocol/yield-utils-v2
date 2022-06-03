// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;


library CastBytes32Bytes12 {
    function b12(bytes32 x) internal pure returns (bytes12 y) {
        require (bytes32(y = bytes12(x)) == x, "Cast overflow");
    }
}