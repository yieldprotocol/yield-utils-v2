// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


interface IEmergencyBrake {
    struct Permission {
        address contact; /// contract for which a user holds auth priviliges
        bytes4[] signatures;
    }

    function plan(address target, Permission[] calldata permissions) external;
    function addToPlan(address target, Permission calldata permission) external;
    function removeFromPlan(address target, Permission calldata permission) external;
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
contract EmergencyBrake is AccessControl, IEmergencyBrake {
    enum State {UNPLANNED, PLANNED, EXECUTED}

    struct Plan {
        State state;
        address target;
        Permission[] permissions;
    }

    event Planned(address indexed target, Permission[] permissions);
    event AddedTo(address indexed target, Permission toAdd);
    event RemovedFrom(address indexed target, Permission toRemove);
    event Cancelled(address indexed target);
    event Executed(address indexed target);
    event Restored(address indexed target);
    event Terminated(address indexed target);

    mapping (address => Plan) public plans;
    mapping (bytes => uint256) public permissionIndex;

    constructor(address planner, address executor) AccessControl() {
        _grantRole(IEmergencyBrake.plan.selector, planner);
        _grantRole(IEmergencyBrake.addToPlan.selector, planner);
        _grantRole(IEmergencyBrake.removeFromPlan.selector, planner);
        _grantRole(IEmergencyBrake.cancel.selector, planner);
        _grantRole(IEmergencyBrake.execute.selector, executor);
        _grantRole(IEmergencyBrake.restore.selector, planner);
        _grantRole(IEmergencyBrake.terminate.selector, planner);
        // Granting roles (plan, cancel, execute, restore, terminate, modifyPlan) is reserved to ROOT
    }

    /// @dev Register an access removal transaction
    /// @param target address with auth privileges on contracts
    function plan(address target, Permission[] calldata permissions)
        external override auth
    {
        require(plans[target].state == State.UNPLANNED, "Emergency already planned for.");

        // Removing or granting ROOT permissions is out of bounds for EmergencyBrake
        for (uint256 i = 0; i < permissions.length; i++){
            Permission memory _permission = permissions[i];
            for (uint256 j = 0; j < permissions[i].signatures.length;){
                require(
                    permissions[i].signatures[j] != ROOT,
                    "Can't remove ROOT"
                );
                unchecked{++j;}
            }
            plans[target].permissions.push(permissions[i]);
            bytes memory toIndex = abi.encode(_permission);
            unchecked{++i;}
            permissionIndex[toIndex] = i;
        }

        plans[target].state = State.PLANNED;
        plans[target].target = target;
        emit Planned(target, permissions);
    }

    /// @dev add a permission set to remove for a contact to an existing plan
    /// @dev a contact can be added multiple times to a plan but ensures that all signatures are unique to prevent revert on execution
    /// @param target address with auth privileges on a contract and a plan exists for
    /// @param toAdd permission set that is being added to an existing plan
    function addToPlan(address target, Permission calldata toAdd)
        external override auth 
    {   
        Permission[] memory _permissions = plans[target].permissions;
        require(plans[target].state == State.PLANNED, "Target not planned for");

        
        
        for(uint i; i < _permissions.length;) {
            if(_permissions[i].contact == toAdd.contact){
                for(uint j; j < _permissions[i].signatures.length;){
                    for(uint k; k < toAdd.signatures.length;){
                        require(toAdd.signatures[k] != ROOT, "Can't remove ROOT");
                        require(_permissions[i].signatures[j] != toAdd.signatures[k], "Signature already in plan");
                        unchecked{++k;}
                    }
                    unchecked{++j;}
                }
            }    
            unchecked{++i;}
        }
         
        bytes memory toIndex = abi.encode(toAdd);
        uint256 planId = _permissions.length;
        require(permissionIndex[toIndex] == 0, "Permission set already in plan");
        plans[target].permissions.push(toAdd);
        permissionIndex[toIndex] = planId;
        
        emit AddedTo(target, toAdd);
    }

    /// @dev remove a permission set from an existing plan
    /// @dev retains the order of permissions and updates their index
    /// @param target address wuth auth privileges on a contract and a plan exists for
    function removeFromPlan(address target, Permission calldata toRemove) 
        external override auth
    {
        require(plans[target].state == State.PLANNED, "Target not planned for");
        bytes memory toUnindex = abi.encode(toRemove);
        require(permissionIndex[toUnindex] != 0, "Permission set not planned for");
        uint256 planId = permissionIndex[toUnindex] - 1;
        for(uint i = planId; i < plans[target].permissions.length - 1;)
        {
            plans[target].permissions[i] = plans[target].permissions[i + 1];
            bytes memory toIndex = abi.encode(plans[target].permissions[i]);
            unchecked{++i;}
            permissionIndex[toIndex] = i;
        }
        plans[target].permissions.pop();
        permissionIndex[toUnindex] = 0;
        emit RemovedFrom(target, toRemove);
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

        Permission[] memory permissions_ = plan_.permissions;

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

        Permission[] memory permissions_ = plan_.permissions;

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