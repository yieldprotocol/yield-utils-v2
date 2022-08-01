// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import '@yield-protocol/utils-v2/access/AccessControl.sol';

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */

contract Pausable is AccessControl {

    /// @dev Emitted when contract's pause state is modified
    event PausedState(address indexed account, bool indexed state);

    bool public _paused;

    
    /// @dev Initializes the contract in unpaused state.
    constructor() {
        _paused = false;
    }

    /// @dev Returns true if the contract is paused, and false otherwise
    function paused() external view returns (bool) {
        return _paused;
    }

    /// @dev Triggers paused state. Requires: contract must not be paused
    function _pause() internal virtual auth whenNotPaused {
        _paused = true;
        emit PausedState(msg.sender, _paused);
    }

    /// @dev Returns to active state. Requires: contract must be paused
    function _unpause() internal virtual auth whenPaused {
        _paused = false;
        emit PausedState(msg.sender, _paused);
    }


    /// @dev Modifier to make a function callable only when the contract is not paused
    modifier whenNotPaused() {
        require(_paused == false, "Pausable: paused");
        _;
    }

    /// @dev Modifier to make a function callable only when the contract is paused
    modifier whenPaused() {
        require(_paused == true, "Pausable: not paused");
        _;
    }
}