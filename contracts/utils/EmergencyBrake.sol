// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


interface IEmergencyBrake {
    function plan(address target, address[] memory contacts, bytes4[][] memory signatures) external;
    function erase(address target, address[] memory contacts, bytes4[][] memory signatures) external;
    function isolate(address target, address[] memory contacts, bytes4[][] memory signatures) external;
    function restore(address target, address[] memory contacts, bytes4[][] memory signatures) external;
    function terminate(address target, address[] memory contacts, bytes4[][] memory signatures) external;
}

/// @dev EmergencyBrake allows to plan for and execute isolation transactions that remove access permissions for
/// a target contract from a series of contacts. In an permissioned environment can be used for pausing components.
contract EmergencyBrake is AccessControl, IEmergencyBrake {
    enum State {UNKNOWN, PLANNED, ISOLATED, TERMINATED}

    event Planned(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] signatures);
    event Erased(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] signatures);
    event Isolated(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] signatures);
    event Restored(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] signatures);
    event Terminated(bytes32 indexed txHash, address indexed target, address[] indexed contacts, bytes4[][] signatures);

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
    function plan(address target, address[] memory contacts, bytes4[][] memory signatures)
        external override auth
    {
        require(contacts.length == signatures.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, signatures));
        require(plans[txHash] == State.UNKNOWN, "Plan not unknown.");
        plans[txHash] = State.PLANNED;
        emit Planned(txHash, target, contacts, signatures);
    }

    /// @dev Erase a planned isolation transaction
    function erase(address target, address[] memory contacts, bytes4[][] memory signatures)
        external override auth
    {
        require(contacts.length == signatures.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, signatures));
        require(plans[txHash] == State.PLANNED, "Transaction not planned.");
        plans[txHash] = State.UNKNOWN;
        emit Erased(txHash, target, contacts, signatures);
    }

    /// @dev Execute an isolation transaction
    function isolate(address target, address[] memory contacts, bytes4[][] memory signatures)
        external override auth
    {
        require(contacts.length == signatures.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, signatures));
        require(plans[txHash] == State.PLANNED, "Transaction not planned.");
        plans[txHash] = State.ISOLATED;

        for (uint256 i = 0; i < contacts.length; i++){
            AccessControl(contacts[i]).revokeRoles(signatures[i], target);
        }
        emit Isolated(txHash, target, contacts, signatures);
    }

    /// @dev Restore the orchestration from an isolated target
    function restore(address target, address[] memory contacts, bytes4[][] memory signatures)
        external override auth
    {
        require(contacts.length == signatures.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, signatures));
        require(plans[txHash] == State.ISOLATED, "Target not isolated.");
        plans[txHash] = State.PLANNED;

        for (uint256 i = 0; i < contacts.length; i++){
            AccessControl(contacts[i]).grantRoles(signatures[i], target);
        }
        emit Restored(txHash, target, contacts, signatures);
    }

    /// @dev Remove the restoring option from an isolated target
    function terminate(address target, address[] memory contacts, bytes4[][] memory signatures)
        external override auth
    {
        require(contacts.length == signatures.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(target, contacts, signatures));
        require(plans[txHash] == State.ISOLATED, "Target not isolated.");
        plans[txHash] = State.TERMINATED;
        emit Terminated(txHash, target, contacts, signatures);
    }
}