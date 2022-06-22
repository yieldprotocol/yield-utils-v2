// SPDX-License-Identifier: MIT
// Taken from https://github.com/Uniswap/uniswap-lib/blob/master/contracts/libraries/TransferHelper.sol

pragma solidity >=0.6.0;

import "./IERC20.sol";
import "../utils/RevertMsgExtractor.sol";


// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    /// @notice Transfers tokens from msg.sender to a recipient
    /// @dev Errors with the underlying revert message if transfer fails
    /// @param token The contract address of the token which will be transferred
    /// @param to The recipient of the transfer
    /// @param value The value of the transfer
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert(RevertMsgExtractor.getRevertMsg(data));
    }

    /// @notice Transfers tokens from the targeted address to the given destination
    /// @dev Errors with the underlying revert message if transfer fails
    /// @param token The contract address of the token to be transferred
    /// @param from The originating address from which the tokens will be transferred
    /// @param to The destination address of the transfer
    /// @param value The amount to be transferred
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert(RevertMsgExtractor.getRevertMsg(data));
    }

    /// @notice Transfers ETH to the recipient address
    /// @dev Errors with the underlying revert message if transfer fails
    /// @param to The destination of the transfer
    /// @param value The value to be transferred
    function safeTransferETH(address payable to, uint256 value) internal {
        (bool success, bytes memory data) = to.call{value: value}(new bytes(0));
        if (!success) revert(RevertMsgExtractor.getRevertMsg(data));
    }

    /// @notice Increase the allowance for this token. Prefer this over
    ///     `approve` to prevent frontrunning.
    /// @param token The token to increase allowance on.
    /// @param spender The spender of the tokens.
    /// @param value The additional allowance to provide to the spender.
    /// @dev Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/7c75b8aa89073376fb67d78a40f6d69331092c94/contracts/token/ERC20/utils/SafeERC20.sol
    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert(RevertMsgExtractor.getRevertMsg(data));
    }

    /// @notice Decrease the allowance for this token.  Prefer this over
    ///     `approve` to prevent frontrunning.
    /// @param token The token to decrease allowance on.
    /// @param spender The spender of the tokens.
    /// @param value The allowance to remove from the spender.
    /// @dev Based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/7c75b8aa89073376fb67d78a40f6d69331092c94/contracts/token/ERC20/utils/SafeERC20.sol
    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
            if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert(RevertMsgExtractor.getRevertMsg(data));
        }
    }
}
