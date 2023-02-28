// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @dev ETHBalance is a simple contract to get the ETH balance of an address.
contract ETHBalance {

    /// @dev Returns the ETH balance of an address.
    function getBalance(address addr) external view returns (uint256) {
        return addr.balance;
    }
}