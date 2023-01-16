// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/console2.sol";

/// @notice Compare values on-chain, and revert if the comparison fails.
/// This contract is useful to append checks at in a batch of transactions, so that
/// if any of the checks fail, the entire batch of transactions will revert.
contract Assert {

    /// --- EQUALITY ---

    /// @notice Compare two bytes for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(bytes memory actual, bytes memory expected)
        public
        pure
    {
        require(keccak256(actual) == keccak256(expected), "Not equal to expected");
    }
    
    /// @notice Compare two booleans for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(bool actual, bool expected)
        public
        pure
    {
        require(actual == expected, "Not equal to expected");
    }

    /// @notice Compare two uint values for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(uint actual, uint expected)
        public
        pure
    {
        require(actual == expected, "Not equal to expected");
    }

    /// @notice Compare a function output to an expected value for equality
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        assertEq(abi.decode(actual, (uint)), expected);
    }

    /// @notice Compare two function outputs for equality
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertEq(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        assertEq(abi.decode(actual, (uint)), abi.decode(expected, (uint)));
    }

    /// --- RELATIVE EQUALITY ---

    /// @notice Compare two uint for equality, within a relative tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    function assertEqRel(uint actual, uint expected, uint rel)
        public
        pure
    {
        require(actual <= expected * (1e18 + rel) / 1e18, "Higher than expected");
        require(actual >= expected * (1e18 - rel) / 1e18, "Lower than expected");
    }

    /// @notice Compare a function output to an expected value for equality, within a relative tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    function assertEqRel(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        uint256 rel
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        assertEqRel(abi.decode(actual, (uint)), expected, rel);
    }

    /// @notice Compare two function outputs for equality, within a relative tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    function assertEqRel(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        uint256 rel
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);
        assertEqRel(abi.decode(actual, (uint)), abi.decode(expected, (uint)), rel);
    }

    /// --- ABSOLUTE EQUALITY ---

    /// @notice Compare two uint for equality, within an absolute tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function assertEqAbs(uint actual, uint expected, uint abs)
        public
        pure
    {
        require(actual <= expected + abs, "Higher than expected");
        require(actual >= expected - abs, "Lower than expected");
    }

    /// @notice Compare a function output to an expected value for equality, within an absolute tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function assertEqAbs(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        uint256 abs
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        assertEqRel(abi.decode(actual, (uint)), expected, abs);
    }

    /// @notice Compare two function outputs for equality, within an absolute tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function assertEqAbs(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        uint256 abs
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);
        assertEqRel(abi.decode(actual, (uint)), abi.decode(expected, (uint)), abs);
    }

    /// --- GREATER THAN ---

    /// @notice Check that an actual value is greater than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertGt(uint actual, uint expected)
        public
        pure
    {
        require(actual > expected, "Not greater than expected");
    }

    /// @notice Check that a function output is greater than an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertGt(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        assertGt(abi.decode(actual, (uint)), expected);
    }

    /// @notice Check that the a function output is greater than the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertGt(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        assertGt(abi.decode(actual, (uint)), abi.decode(expected, (uint)));
    }

    /// --- LESS THAN ---

    /// @notice Check that an actual value is less than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertLt(uint actual, uint expected)
        public
        pure
    {
        require(actual < expected, "Not less than expected");
    }

    /// @notice Check that a function output is less than an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertLt(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        assertLt(abi.decode(actual, (uint)), expected);
    }

    /// @notice Check that the a function output is less than the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertLt(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        assertLt(abi.decode(actual, (uint)), abi.decode(expected, (uint)));
    }

    /// --- GREATER OR EQUAL ---

    /// @notice Check that an actual value is greater or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertGe(uint actual, uint expected)
        public
        pure
    {
        require(actual >= expected, "Not greater or equal to expected");
    }

    /// @notice Check that a function output is greater or equal to an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertGe(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        assertGe(abi.decode(actual, (uint)), expected);
    }

    /// @notice Check that the a function output is greater or equal to the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertGe(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        assertGe(abi.decode(actual, (uint)), abi.decode(expected, (uint)));
    }

    /// --- LESS THAN ---

    /// @notice Check that an actual value is less or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertLe(uint actual, uint expected)
        public
        pure
    {
        require(actual <= expected, "Not less or equal to expected");
    }

    /// @notice Check that a function output is less or equal to an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertLe(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        assertLe(abi.decode(actual, (uint)), expected);
    }

    /// @notice Check that the a function output is less or equal to the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertLe(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        assertLe(abi.decode(actual, (uint)), abi.decode(expected, (uint)));
    }
}
