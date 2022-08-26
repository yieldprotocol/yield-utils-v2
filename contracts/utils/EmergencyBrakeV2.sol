// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


interface IEmergencyBrake {
    struct Permission {
        address contact;
        bytes4[] signatures;
    }

    function plan(address target, string calldata planName, Permission[] calldata permissions) external;
    function cancel(address target, string calldata planName) external;
    function execute(address target, string calldata planName) external;
    function restore(address target, string calldata planName) external;
    function terminate(address target, string calldata planName) external;
}

/// @dev EmergencyBrake allows to plan for and execute transactions that remove access permissions for a target
/// contract. In an permissioned environment this can be used for pausing components.
/// All contracts in scope of emergency plans must grant ROOT permissions to EmergencyBrake. To mitigate the risk
/// of governance capture, EmergencyBrake has very limited functionality, being able only to revoke existing roles
/// and to restore previously revoked roles. Thus EmergencyBrake cannot grant permissions that weren't there in the 
/// first place. As an additional safeguard, EmergencyBrake cannot revoke or grant ROOT roles.
/// In addition, there is a separation of concerns between the planner and the executor accounts, so that both of them
/// must be compromised simultaneously to execute non-approved emergency plans, and then only creating a denial of service.
contract EmergencyBrakeV2 is AccessControl, IEmergencyBrake {
    enum State {UNPLANNED, PLANNED, EXECUTED}

    struct Plan {
        State state;
        address target;
        bytes permissions;
    }

    event Planned(address indexed target, string planName);
    event Cancelled(address indexed target, string planName);
    event Executed(address indexed target, string planName);
    event Restored(address indexed target, string planName);
    event Terminated(address indexed target, string planName);

    mapping (address => mapping(string => Plan)) public plans;

    constructor(address planner, address executor) AccessControl() {
        _grantRole(IEmergencyBrake.plan.selector, planner);
        _grantRole(IEmergencyBrake.cancel.selector, planner);
        _grantRole(IEmergencyBrake.execute.selector, executor);
        _grantRole(IEmergencyBrake.restore.selector, planner);
        _grantRole(IEmergencyBrake.terminate.selector, planner);

        // Granting roles (plan, cancel, execute, restore, terminate) is reserved to ROOT
    }

    /// @dev Compute the hash of a plan
    function hash(address target, Permission[] calldata permissions)
        external pure
        returns (bytes32 txHash)
    {
        txHash = keccak256(abi.encode(target, permissions));
    }

    /// @dev Register an access removal transaction
    function plan(address target, string calldata planName, Permission[] calldata permissions)
        external override auth
    {
        require(plans[target][planName].state == State.UNPLANNED, "Emergency already planned for.");

        // Removing or granting ROOT permissions is out of bounds for EmergencyBrake
        for (uint256 i = 0; i < permissions.length; i++){
            for (uint256 j = 0; j < permissions[i].signatures.length; j++){
                require(
                    permissions[i].signatures[j] != ROOT,
                    "Can't remove ROOT"
                );
            }
        }

        plans[target][planName] = Plan({
            state: State.PLANNED,
            target: target,
            permissions: abi.encode(permissions)
        });
        emit Planned(target, planName);
    }

    /// @dev Erase a planned access removal transaction
    function cancel(address target, string calldata planName)
        external override auth
    {
        require(plans[target][planName].state == State.PLANNED, "Emergency not planned for.");
        delete plans[target][planName];
        emit Cancelled(target, planName);
    }

    /// @dev Execute an access removal transaction
    function execute(address target, string calldata planName)
        external override auth
    {
        Plan memory plan_ = plans[target][planName];
        require(plan_.state == State.PLANNED, "Emergency not planned for.");
        plans[target][planName].state = State.EXECUTED;

        Permission[] memory permissions_ = abi.decode(plan_.permissions, (Permission[]));

        for (uint256 i = 0; i < permissions_.length; i++){
            // AccessControl.sol doesn't revert if revoking permissions that haven't been granted
            // If we don't check, planner and executor can collude to gain access to contacts
            Permission memory permission_ = permissions_[i]; 
            for (uint256 j = 0; j < permission_.signatures.length; j++){
                AccessControl contact = AccessControl(permission_.contact);
                bytes4 signature_ = permission_.signatures[j];
                require(
                    contact.hasRole(signature_, plan_.target),
                    "Permission not found"
                );
                contact.revokeRole(signature_, plan_.target);
            }
        }
        emit Executed(target, planName);
    }

    /// @dev Restore the orchestration from an isolated target
    function restore(address target, string calldata planName)
        external override auth
    {
        Plan memory plan_ = plans[target][planName];
        require(plan_.state == State.EXECUTED, "Emergency plan not executed.");
        plans[target][planName].state = State.PLANNED;

        Permission[] memory permissions_ = abi.decode(plan_.permissions, (Permission[]));

        for (uint256 i = 0; i < permissions_.length; i++){
            Permission memory permission_ = permissions_[i]; 
            for (uint256 j = 0; j < permission_.signatures.length; j++){
                AccessControl contact = AccessControl(permission_.contact);
                bytes4 signature_ = permission_.signatures[j];
                contact.grantRole(signature_, plan_.target);
            }
        }
        emit Restored(target, planName);
    }

    /// @dev Remove the restoring option from an isolated target
    function terminate(address target, string calldata planName)
        external override auth
    {
        require(plans[target][planName].state == State.EXECUTED, "Emergency plan not executed.");
        delete plans[target][planName];
        emit Terminated(target, planName);
    }
}