// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


interface IEmergencyBrake {
    struct Permission {
        address contact;
        bytes4[] signatures;
    }

    function plan(address target, Permission[] calldata permissions) external;
    function modifyPlan(address target, Permission[] calldata permissions) external;
    function addToPlan(address target, Permission[] calldata permissions) external;
    function removeFromPlan(address target, Permission[] calldata permissions) external;
    function cancel(address target) external;
    function execute(address target) external;
    function restore(address target) external;
    function terminate(address target) external;
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

    event Planned(address indexed target);
    event Modified(address indexed target);
    event Cancelled(address indexed target);
    event Executed(address indexed target);
    event Restored(address indexed target);
    event Terminated(address indexed target);

    mapping (address => Plan) public plans;

    Permission[] private _tempPermissions;

    constructor(address planner, address executor) AccessControl() {
        _grantRole(IEmergencyBrake.plan.selector, planner);
        _grantRole(IEmergencyBrake.modifyPlan.selector, planner);
        _grantRole(IEmergencyBrake.addToPlan.selector, planner);
        _grantRole(IEmergencyBrake.cancel.selector, planner);
        _grantRole(IEmergencyBrake.execute.selector, executor);
        _grantRole(IEmergencyBrake.restore.selector, planner);
        _grantRole(IEmergencyBrake.terminate.selector, planner);
        // Granting roles (plan, cancel, execute, restore, terminate, modifyPlan) is reserved to ROOT
    }

    /// @dev Register an access removal transaction
    function plan(address target, Permission[] calldata permissions)
        external override auth
    {
        require(plans[target].state == State.UNPLANNED, "Emergency already planned for.");

        // Removing or granting ROOT permissions is out of bounds for EmergencyBrake
        for (uint256 i = 0; i < permissions.length; i++){
            for (uint256 j = 0; j < permissions[i].signatures.length; j++){
                require(
                    permissions[i].signatures[j] != ROOT,
                    "Can't remove ROOT"
                );
            }
        }

        plans[target] = Plan({
            state: State.PLANNED,
            target: target,
            permissions: abi.encode(permissions)
        });
        emit Planned(target);
    }

    /// @dev Alter targetted permissions of an existing plan
    function modifyPlan(address target, Permission[] calldata permissions)
        external override auth
    {
        require(plans[target].state == State.PLANNED, "Emergency not planned for.");
        // Removing or granting ROOT permissions is out of bounds for EmergencyBrake
        for (uint256 i = 0; i < permissions.length; i++){
            for (uint256 j = 0; j < permissions[i].signatures.length; j++){
                require(
                    permissions[i].signatures[j] != ROOT,
                    "Can't remove ROOT"
                );
            }
        }
        plans[target].permissions = abi.encode(permissions);
        emit Modified(target);
    }

    function addToPlan(address target, Permission[] calldata newPermissions)
        external override auth 
    {
        _tempPermissions = abi.decode(plans[target].permissions, (Permission[]));
        Permission[] memory _permissions = abi.decode(plans[target].permissions, (Permission[]));
        for(uint i = 0; i < newPermissions.length; ++i){
            bool contactMatch = false;
            for(uint j = 0; j < _permissions.length; ++j) {
                if(_permissions[j]. contact == newPermissions[i].contact) {
                    contactMatch = true;
                    for(uint k = 0; k < newPermissions[i].signatures.length; ++k) {
                        bool signatureMatch = false;
                        for(uint m = 0; m < _permissions[j].signatures.length; ++m) {
                            if(newPermissions[i].signatures[k] == _permissions[j].signatures[m]){
                                signatureMatch = true;
                            }
                        } 
                        if(!signatureMatch) {
                            _tempPermissions[j].signatures.push(newPermissions[i].signatures[k]);
                        }
                    }
                }
            }
            if(!contactMatch) {
                _tempPermissions.push(newPermissions[i]);
            }  
        }
        plans[target].permissions = abi.encode(_tempPermissions);
        delete _tempPermissions;
    }

    function removeFromPlan(address target, Permission[] calldata permissions) 
        external override auth
    {

    }


    /// @dev Erase a planned access removal transaction
    function cancel(address target)
        external override auth
    {
        require(plans[target].state == State.PLANNED, "Emergency not planned for.");
        delete plans[target];
        emit Cancelled(target);
    }

    /// @dev Execute an access removal transaction
    function execute(address target)
        external override auth
    {
        Plan memory plan_ = plans[target];
        require(plan_.state == State.PLANNED, "Emergency not planned for.");
        plans[target].state = State.EXECUTED;

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
        emit Executed(target);
    }

    /// @dev Restore the orchestration from an isolated target
    function restore(address target)
        external override auth
    {
        Plan memory plan_ = plans[target];
        require(plan_.state == State.EXECUTED, "Emergency plan not executed.");
        plans[target].state = State.PLANNED;

        Permission[] memory permissions_ = abi.decode(plan_.permissions, (Permission[]));

        for (uint256 i = 0; i < permissions_.length; i++){
            Permission memory permission_ = permissions_[i]; 
            for (uint256 j = 0; j < permission_.signatures.length; j++){
                AccessControl contact = AccessControl(permission_.contact);
                bytes4 signature_ = permission_.signatures[j];
                contact.grantRole(signature_, plan_.target);
            }
        }
        emit Restored(target);
    }

    /// @dev Remove the restoring option from an isolated target
    function terminate(address target)
        external override auth
    {
        require(plans[target].state == State.EXECUTED, "Emergency plan not executed.");
        delete plans[target];
        emit Terminated(target);
    }
}