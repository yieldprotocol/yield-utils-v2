// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { RevertMsgExtractor } from "./RevertMsgExtractor.sol";

library LimitedCall {
    /// @dev Call a function with zero value and 5000 gas, and revert if the call fails.
    function limitedCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory output) = target.call{value: 0, gas: 5000}(data);
        if (!success) {
            revert(RevertMsgExtractor.getRevertMsg(output));
        } else {
            return output;
        }
    }
}

/// @notice Compare values on-chain, and revert if the comparison fails.
/// This contract is useful to append checks at in a batch of transactions, so that
/// if any of the checks fail, the entire batch of transactions will revert.
contract Assert {
    using LimitedCall for address;

    /// --- EQUALITY ---

    /// @notice Compare two bytes for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function _assertEq(bytes memory actual, bytes memory expected, string memory errmsg)
        internal
        pure
    {
        require(keccak256(actual) == keccak256(expected), errmsg);
    }

    /// @notice Compare two bytes for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(bytes memory actual, bytes memory expected)
        public
        pure
    {
        _assertEq(actual, expected, "Not equal to expected");
    }

    /// @notice Compare two bytes for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEq(bytes memory actual, bytes memory expected, string memory errmsg)
        public
        pure
    {
        _assertEq(actual, expected, errmsg);
    }
    
    /// @notice Compare two booleans for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(bool actual, bool expected)
        public
        pure
    {
        _assertEq(abi.encode(actual), abi.encode(expected), "Not equal to expected");
    }

    /// @notice Compare two booleans for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEq(bool actual, bool expected, string memory errmsg)
        public
        pure
    {
        _assertEq(abi.encode(actual), abi.encode(expected), errmsg);
    }

    /// @notice Compare two uint values for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertEq(uint actual, uint expected)
        public
        pure
    {
        _assertEq(abi.encode(actual), abi.encode(expected), "Not equal to expected");
    }

    /// @notice Compare two uint values for equality
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEq(uint actual, uint expected, string memory errmsg)
        public
        pure
    {
        _assertEq(abi.encode(actual), abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertEq(actual, abi.encode(expected), "Not equal to expected");
    }

    /// @notice Compare a function output to an expected value for equality
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEq(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertEq(actual, abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);

        _assertEq(actual, expected, "Not equal to expected");
    }

    /// @notice Compare two function outputs for equality
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEq(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);

        _assertEq(actual, expected, errmsg);
    }

    /// --- RELATIVE EQUALITY ---

    /// @notice Compare two uint for equality, within a relative tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    /// @param errmsg The error message to revert with if the comparison fails
    function _assertEqRel(bytes memory  actual, bytes memory expected, uint rel, string memory errmsg)
        internal
        pure
    {
        uint actual_ = abi.decode(actual, (uint));
        uint expected_ = abi.decode(expected, (uint));
        require(actual_ <= expected_ * (1e18 + rel) / 1e18 && actual_ >= expected_ * (1e18 - rel) / 1e18, errmsg);
    }

    /// @notice Compare two uint for equality, within a relative tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEqRel(uint actual, uint expected, uint rel, string memory errmsg)
        public
        pure
    {
        _assertEqRel(abi.encode(actual), abi.encode(expected), rel, errmsg);
    }

    /// @notice Compare two uint for equality, within a relative tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    function assertEqRel(uint actual, uint expected, uint rel)
        public
        pure
    {
        _assertEqRel(abi.encode(actual), abi.encode(expected), rel, "Not within expected range");
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertEqRel(actual, abi.encode(expected), rel, "Not within expected range");
    }

    /// @notice Compare a function output to an expected value for equality, within a relative tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEqRel(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        uint256 rel,
        string memory errmsg
    )
        public
    {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertEqRel(actual, abi.encode(expected), rel, errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertEqRel(actual, expected, rel, "Not within expected range");
    }

    /// @notice Compare two function outputs for equality, within a relative tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param rel The relative tolerance for the equality, with 18 decimals of precision. 10e16 is ±1%
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEqRel(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        uint256 rel,
        string memory errmsg
    )
        public
    {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertEqRel(actual, expected, rel, errmsg);
    }

    /// --- ABSOLUTE EQUALITY ---

    /// @notice Compare two uint for equality, within an absolute tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function _assertEqAbs(bytes memory actual, bytes memory expected, uint abs, string memory errmsg)
        public
        pure
    {
        uint actual_ = abi.decode(actual, (uint));
        uint expected_ = abi.decode(expected, (uint));
        require(actual_ <= expected_ + abs && actual_ >= expected_ - abs, errmsg);
    }

    /// @notice Compare two uint for equality, within an absolute tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    function assertEqAbs(uint actual, uint expected, uint abs)
        public
        pure
    {
        _assertEqAbs(abi.encode(actual), abi.encode(expected), abs, "Not within expected range");
    }

    /// @notice Compare two uint for equality, within an absolute tolerance
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEqAbs(uint actual, uint expected, uint abs, string memory errmsg)
        public
        pure
    {
        _assertEqAbs(abi.encode(actual), abi.encode(expected), abs, errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertEqAbs(actual, abi.encode(expected), abs, "Not within expected range");
    }

    /// @notice Compare a function output to an expected value for equality, within an absolute tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEqAbs(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        uint256 abs,
        string memory errmsg
    )
        public
    {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertEqAbs(actual, abi.encode(expected), abs, errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertEqAbs(actual, expected, abs, "Not within expected range");
    }

    /// @notice Compare two function outputs for equality, within an absolute tolerance
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param abs The absolute tolerance for equality, with 18 decimals of precision.
    /// @param errmsg The error message to revert with if the comparison fails
    function assertEqAbs(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        uint256 abs,
        string memory errmsg
    )
        public
    {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertEqAbs(actual, expected, abs, errmsg);
    }
    /// --- GREATER THAN ---

    /// @notice Check that an actual value is greater than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function _assertGt(bytes memory actual, bytes memory expected, string memory errmsg)
        public
        pure
    {
        uint actual_ = abi.decode(actual, (uint));
        uint expected_ = abi.decode(expected, (uint));
        require(actual_ > expected_, errmsg);
    }

    /// @notice Check that an actual value is greater than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertGt(uint actual, uint expected)
        public
        pure
    {
        _assertGt(abi.encode(actual), abi.encode(expected), "Not greater than expected");
    }

    /// @notice Check that an actual value is greater than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertGt(uint actual, uint expected, string memory errmsg)
        public
        pure
    {
        _assertGt(abi.encode(actual), abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertGt(actual, abi.encode(expected), "Not greater than expected");
    }

    /// @notice Check that a function output is greater than an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertGt(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertGt(actual, abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);

        _assertGt(actual, expected, "Not greater than expected");
    }

    /// @notice Check that the a function output is greater than the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertGt(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);

        _assertGt(actual, expected, errmsg);
    }

    /// --- LESS THAN ---

    /// @notice Check that an actual value is less than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function _assertLt(bytes memory actual, bytes memory expected, string memory errmsg)
        public
        pure
    {
        uint actual_ = abi.decode(actual, (uint));
        uint expected_ = abi.decode(expected, (uint));
        require(actual_ < expected_, errmsg);
    }

    /// @notice Check that an actual value is less than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertLt(uint actual, uint expected)
        public
        pure
    {
        _assertLt(abi.encode(actual), abi.encode(expected), "Not less than expected");
    }

    /// @notice Check that an actual value is less than the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertLt(uint actual, uint expected, string memory errmsg)
        public
        pure
    {
        _assertLt(abi.encode(actual), abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertLt(actual, abi.encode(expected), "Not less than expected");
    }

    /// @notice Check that a function output is less than an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertLt(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertLt(actual, abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertLt(actual, expected, "Not less than expected");
    }

    /// @notice Check that the a function output is less than the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertLt(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertLt(actual, expected, errmsg);
    }

    /// --- GREATER OR EQUAL ---

    /// @notice Check that an actual value is greater or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function _assertGe(bytes memory actual, bytes memory expected, string memory errmsg)
        public
        pure
    {
        uint actual_ = abi.decode(actual, (uint));
        uint expected_ = abi.decode(expected, (uint));
        require(actual_ >= expected_, errmsg);
    }

    /// @notice Check that an actual value is greater or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertGe(uint actual, uint expected)
        public
        pure
    {
        _assertGe(abi.encode(actual), abi.encode(expected), "Not greater or equal to expected");
    }

    /// @notice Check that an actual value is greater or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertGe(uint actual, uint expected, string memory errmsg)
        public
        pure
    {
        _assertGe(abi.encode(actual), abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertGe(actual, abi.encode(expected), "Not greater or equal to expected");
    }

    /// @notice Check that a function output is greater or equal to an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertGe(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertGe(actual, abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertGe(actual, expected, "Not greater or equal to expected");
    }

    /// @notice Check that the a function output is greater or equal to the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertGe(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertGe(actual, expected, errmsg);
    }

    /// --- LESS THAN ---

    /// @notice Check that an actual value is less or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function _assertLe(bytes memory actual, bytes memory expected, string memory errmsg)
        public
        pure
    {
        uint actual_ = abi.decode(actual, (uint));
        uint expected_ = abi.decode(expected, (uint));
        require(actual_ <= expected_, errmsg);
    }

    /// @notice Check that an actual value is less or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    function assertLe(uint actual, uint expected)
        public
        pure
    {
        _assertLe(abi.encode(actual), abi.encode(expected), "Not less or equal to expected");
    }

    /// @notice Check that an actual value is less or equal to the expected value
    /// @param actual The value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertLe(uint actual, uint expected, string memory errmsg)
        public
        pure
    {
        _assertLe(abi.encode(actual), abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertLe(actual, abi.encode(expected), "Not less or equal to expected");
    }

    /// @notice Check that a function output is less or equal to an expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expected The value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertLe(
        address actualTarget,
        bytes memory actualCalldata,
        uint expected,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        _assertLe(actual, abi.encode(expected), errmsg);
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
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertLe(actual, expected, "Not less or equal to expected");
    }

    /// @notice Check that the a function output is less or equal to the output of another function providing the expected value
    /// @param actualTarget The contract that will provide the value we are comparing
    /// @param actualCalldata The encoded function call that will provide the value we are comparing
    /// @param expectedTarget The contract that will provide the value we want to obtain
    /// @param expectedCalldata The encoded function call that will provide the value we want to obtain
    /// @param errmsg The error message to revert with if the comparison fails
    function assertLe(
        address actualTarget,
        bytes memory actualCalldata,
        address expectedTarget,
        bytes memory expectedCalldata,
        string memory errmsg
    ) public {
        bytes memory actual = actualTarget.limitedCall(actualCalldata);
        bytes memory expected = expectedTarget.limitedCall(expectedCalldata);
        _assertLe(actual, expected, errmsg);
    }
}
