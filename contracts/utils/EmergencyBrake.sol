// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


interface IEmergencyBrake {
    function plan(address target, address[] memory contacts, bytes4[][] memory permissions) external;
    function erase(address target, address[] memory contacts, bytes4[][] memory permissions) external;
    function isolate(address target, address[] memory contacts, bytes4[][] memory permissions) external;
    function restore(address target, address[] memory contacts, bytes4[][] memory permissions) external;
    function terminate(address target, address[] memory contacts, bytes4[][] memory permissions) external;
}

/// @dev EmergencyBrake allows to plan for and execute isolation transactions that remove access permissions for
/// a target contract from a series of contacts. In an permissioned environment can be used for pausing components.
contract EmergencyBrake is AccessControl, IEmergencyBrake {
    enum State {UNKNOWN, PLANNED, ISOLATED, TERMINATED}

    event Planned(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] permissions);
    event Erased(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] permissions);
    event Isolated(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] permissions);
    event Restored(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] permissions);
    event Terminated(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] permissions);

    mapping (bytes32 => State) public plans;

    constructor(address planner, address isolator) AccessControl() {
        _grantRole(IEmergencyBrake.plan.selector, planner);
        _grantRole(IEmergencyBrake.erase.selector, planner);
        _grantRole(IEmergencyBrake.isolate.selector, isolator);
        _grantRole(IEmergencyBrake.restore.selector, planner);
        _grantRole(IEmergencyBrake.terminate.selector, planner);

        // Granting roles (plan, erase, isolate, restore, terminate) is reserved to ROOT
    }

    /// @dev Register an isolation transaction
    function plan(address target, address[] memory contacts, bytes4[][] memory permissions)
        external override auth
    {
        require(contacts.length == permissions.length, "Mismatched inputs");
        // Removing or granting ROOT permissions is out of bounds for EmergencyBrake
        for (uint256 i = 0; i < contacts.length; i++){
            for (uint256 j = 0; i < permissions[i].length; i++){
                require(
                    permissions[i][j] != ROOT,
                    "Can't remove ROOT"
                );
            }
        }
        bytes32 txHash = keccak256(abi.encode(target, contacts, permissions));
        require(plans[txHash] == State.UNKNOWN, "Plan not unknown.");
        plans[txHash] = State.PLANNED;
        emit Planned(txHash, target, contacts, permissions);
    }

    /// @dev Erase a planned isolation transaction
    function erase(address target, address[] memory contacts, bytes4[][] memory permissions)
        external override auth
    {
        require(contacts.length == permissions.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, permissions));
        require(plans[txHash] == State.PLANNED, "Transaction not planned.");
        plans[txHash] = State.UNKNOWN;
        emit Erased(txHash, target, contacts, permissions);
    }

    /// @dev Execute an isolation transaction
    function isolate(address target, address[] memory contacts, bytes4[][] memory permissions)
        external override auth
    {
        require(contacts.length == permissions.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, permissions));
        require(plans[txHash] == State.PLANNED, "Transaction not planned.");
        plans[txHash] = State.ISOLATED;

        for (uint256 i = 0; i < contacts.length; i++){
            // AccessControl.sol doesn't revert if revoking permissions that haven't been granted
            // If we don't check, planner and isolator can collude to gain access to contacts
            for (uint256 j = 0; i < permissions[i].length; i++){
                require(
                    AccessControl(contacts[i]).hasRole(permissions[i][j], target),
                    "Permission not found"
                );
            }
            // Now revoke the permissions
            AccessControl(contacts[i]).revokeRoles(permissions[i], target);
        }
        emit Isolated(txHash, target, contacts, permissions);
    }

    /// @dev Restore the orchestration from an isolated target
    function restore(address target, address[] memory contacts, bytes4[][] memory permissions)
        external override auth
    {
        require(contacts.length == permissions.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, permissions));
        require(plans[txHash] == State.ISOLATED, "Target not isolated.");
        plans[txHash] = State.PLANNED;

        for (uint256 i = 0; i < contacts.length; i++){
            AccessControl(contacts[i]).grantRoles(permissions[i], target);
        }
        emit Restored(txHash, target, contacts, permissions);
    }

    /// @dev Remove the restoring option from an isolated target
    function terminate(address target, address[] memory contacts, bytes4[][] memory permissions)
        external override auth
    {
        require(contacts.length == permissions.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, permissions));
        require(plans[txHash] == State.ISOLATED, "Target not isolated.");
        plans[txHash] = State.TERMINATED;
        emit Terminated(txHash, target, contacts, permissions);
    }
}