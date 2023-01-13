// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Compare values on-chain, and revert if the comparison fails.
/// This contract is useful to append checks at in a batch of transactions, so that
/// if any of the checks fail, the entire batch of transactions will revert.
contract Assert {

    /// --- EQUALITY ---

    /// @notice Compare two passed values for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(bytes calldata actual, bytes calldata expected)
        public
        pure
    {
        require(keccak256(actual) == keccak256(expected), "Not equal to expected");
    }

    /// @notice Compare two passed values for equality, within a relative tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    function assertEqRel(bytes calldata actual, bytes calldata expected, uint256 rel)
        public
        pure
    {
        require(uint256(keccak256(actual)) <= uint256(keccak256(expected)) * (1e18 + rel) / 1e18, "Higher than expected");
        require(uint256(keccak256(actual)) >= uint256(keccak256(expected)) * (1e18 - rel) / 1e18, "Lower than expected");
    }

    /// @notice Compare two passed values for equality, within an absolute tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function assertEqAbs(bytes calldata actual, bytes calldata expected, uint256 abs)
        public
        pure
    {
        require(uint256(keccak256(actual)) <= uint256(keccak256(expected)) + abs, "Higher than expected");
        require(uint256(keccak256(actual)) >= uint256(keccak256(expected)) - abs, "Lower than expected");
    }

    /// @notice Compare a function output to an expected value for equality
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(
        address actualTarget,
        bytes calldata actualCalldata,
        bytes calldata expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        require(keccak256(actual) == keccak256(expected), "Not equal to expected");
    }

    /// @notice Compare a function output to an expected value for equality, within a relative tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    function assertEqRel(
        address actualTarget,
        bytes calldata actualCalldata,
        bytes calldata expected,
        uint256 rel
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        require(uint256(keccak256(actual)) <= uint256(keccak256(expected)) * (1e18 + rel) / 1e18, "Higher than expected");
        require(uint256(keccak256(actual)) >= uint256(keccak256(expected)) * (1e18 - rel) / 1e18, "Lower than expected");
    }

    /// @notice Compare a function output to an expected value for equality, within an absolute tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function assertEqAbs(
        address actualTarget,
        bytes calldata actualCalldata,
        bytes calldata expected,
        uint256 abs
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        require(uint256(keccak256(actual)) <= uint256(keccak256(expected)) + abs, "Higher than expected");
        require(uint256(keccak256(actual)) >= uint256(keccak256(expected)) - abs, "Lower than expected");
    }


    /// @notice Compare two function outputs for equality
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertEq(
        address actualTarget,
        bytes calldata actualCalldata,
        address expectedTarget,
        bytes calldata expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        require(keccak256(actual) == keccak256(expected), "Not equal to expected");
    }

    /// @notice Compare two function outputs for equality, within a relative tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    function assertEqRel(
        address actualTarget,
        bytes calldata actualCalldata,
        address expectedTarget,
        bytes calldata expectedCalldata,
        uint256 rel
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);
        require(uint256(keccak256(actual)) <= uint256(keccak256(expected)) * (1e18 + rel) / 1e18, "Higher than expected");
        require(uint256(keccak256(actual)) >= uint256(keccak256(expected)) * (1e18 - rel) / 1e18, "Lower than expected");
    }

    /// @notice Compare two function outputs for equality, within an absolute tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function assertEqAbs(
        address actualTarget,
        bytes calldata actualCalldata,
        address expectedTarget,
        bytes calldata expectedCalldata,
        uint256 abs
    )
        public
    {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);
        require(uint256(keccak256(actual)) <= uint256(keccak256(expected)) + abs, "Higher than expected");
        require(uint256(keccak256(actual)) >= uint256(keccak256(expected)) - abs, "Lower than expected");
    }

    /// --- GREATER THAN ---

    /// @notice Check that an actual value is greater than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertGt(bytes calldata actual, bytes calldata expected)
        public
        pure
    {
        require(keccak256(actual) > keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that a function output is greater than an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertGt(
        address actualTarget,
        bytes calldata actualCalldata,
        bytes calldata expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        require(keccak256(actual) > keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that the a function output is greater than the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertGt(
        address actualTarget,
        bytes calldata actualCalldata,
        address expectedTarget,
        bytes calldata expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        require(keccak256(actual) > keccak256(expected), "Not equal to expected");
    }

    /// --- LESS THAN ---

    /// @notice Check that an actual value is less than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertLt(bytes calldata actual, bytes calldata expected)
        public
        pure
    {
        require(keccak256(actual) < keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that a function output is less than an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertLt(
        address actualTarget,
        bytes calldata actualCalldata,
        bytes calldata expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        require(keccak256(actual) < keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that the a function output is less than the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertLt(
        address actualTarget,
        bytes calldata actualCalldata,
        address expectedTarget,
        bytes calldata expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        require(keccak256(actual) < keccak256(expected), "Not equal to expected");
    }

    /// --- GREATER OR EQUAL ---

    /// @notice Check that an actual value is greater or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertGe(bytes calldata actual, bytes calldata expected)
        public
        pure
    {
        require(keccak256(actual) >= keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that a function output is greater or equal to an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertGe(
        address actualTarget,
        bytes calldata actualCalldata,
        bytes calldata expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        require(keccak256(actual) >= keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that the a function output is greater or equal to the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertGe(
        address actualTarget,
        bytes calldata actualCalldata,
        address expectedTarget,
        bytes calldata expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        require(keccak256(actual) >= keccak256(expected), "Not equal to expected");
    }

    /// --- LESS THAN ---

    /// @notice Check that an actual value is less or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertLe(bytes calldata actual, bytes calldata expected)
        public
        pure
    {
        require(keccak256(actual) <= keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that a function output is less or equal to an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    function assertLe(
        address actualTarget,
        bytes calldata actualCalldata,
        bytes calldata expected
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);

        require(keccak256(actual) <= keccak256(expected), "Not equal to expected");
    }

    /// @notice Check that the a function output is less or equal to the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    function assertLe(
        address actualTarget,
        bytes calldata actualCalldata,
        address expectedTarget,
        bytes calldata expectedCalldata
    ) public {
        (, bytes memory actual) = actualTarget.call{value: 0}(actualCalldata);
        (, bytes memory expected) = expectedTarget.call{value: 0}(expectedCalldata);

        require(keccak256(actual) <= keccak256(expected), "Not equal to expected");
    }
}
