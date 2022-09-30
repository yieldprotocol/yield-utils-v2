// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


interface IEmergencyBrake {
    struct Permission {
        address contact; /// contract for which a user holds auth priviliges
        bytes4 signature;
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
        bytes32[] ids;
        mapping(bytes32 => Permission) permissions; ///mapping of bytes32(signature) => position in permissions
    }

    event Planned(address indexed target, Permission[] permissions);
    event PermissionAdded(address indexed target, Permission newPermission);
    event PermissionRemoved(address indexed target, Permission permissionOut);
    event Cancelled(address indexed target);
    event Executed(address indexed target);
    event Restored(address indexed target);
    event Terminated(address indexed target);

    mapping (address => Plan) public plans;

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
    function plan(address target, Permission[] memory permissions)
        external override auth
    {
        Plan storage _plan = plans[target];
        require(_plan.state == State.UNPLANNED, "Emergency already planned for.");
        // Removing or granting ROOT permissions is out of bounds for EmergencyBrake
        for (uint256 i = 0; i < permissions.length; ++i){
            require(
                permissions[i].signature != ROOT,
                "Can't remove ROOT"
            );
            bytes32 newId = _permissionToId(permissions[i]);
            _plan.ids.push(newId);
            _plan.permissions[newId] = permissions[i];
        }
        _plan.state = State.PLANNED;
        emit Planned(target, permissions);
    }

    /// @dev add a permission set to remove for a contact to an existing plan
    /// @dev a contact can be added multiple times to a plan but ensures that all signatures are unique to prevent revert on execution
    /// @param target address with auth privileges on a contract and a plan exists for
    /// @param newPermission permission set that is being added to an existing plan
    function addToPlan(address target, Permission memory newPermission)
        external override auth 
    {   
        Plan storage _plan = plans[target];
        require(_plan.state == State.PLANNED, "Target not planned for");
        require(newPermission.signature != ROOT, "Can't remove ROOT");
        bytes32[] memory _ids = _plan.ids;
        bytes32 newId = _permissionToId(newPermission);
        
        for(uint i; i < _ids.length; ++i){
            require(_ids[i] != newId, "Permission set already in plan");
        }

        _plan.ids.push(newId);
        _plan.permissions[newId] = newPermission;

        emit PermissionAdded(target, newPermission);
    }

    /// @dev remove a permission set from an existing plan
    /// @dev retains the order of permissions and updates their index
    /// @param target address wuth auth privileges on a contract and a plan exists for
    function removeFromPlan(address target, Permission memory permissionOut) 
        external override auth
    {   
        Plan storage _plan = plans[target];
        require(_plan.state == State.PLANNED, "Target not planned for");
        bytes32[] memory _ids = _plan.ids;
        bytes32 idOut = _permissionToId(permissionOut);
        uint256 indexLast = _ids.length - 1; 
        bool idOutInPlan;
        
        if (idOut != _ids[indexLast]) {
            for(uint i; i < _ids.length; ++i){
                if(idOut == _ids[i]){
                    idOutInPlan = true;                           // Flag that idOut was found in the array
                    bytes32 idLast = _ids[indexLast];             // Store the last id in the array
                    _plan.ids[i] = idLast;                        // Replace the outgoing id with the last one in the array
                }
            }
        }
        if (idOut == _ids[indexLast]) {
            idOutInPlan = true;                                   // Flag that idOut is in the array if it matches last one
        }
        require(idOutInPlan, "Permission set not planned");
        _plan.ids.pop();                                          // Shorten the ids array, removing the now duplicated last id
        delete _plan.permissions[idOut];                          // Remove the mapping for the outgoing permission set;
        emit PermissionRemoved(target, permissionOut);
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
        Plan storage _plan = plans[target];
        require(_plan.state == State.PLANNED, "Emergency not planned for.");
        _plan.state = State.EXECUTED;

        bytes32[] memory _ids = _plan.ids;

        for (uint256 i = 0; i < _ids.length; i++){
            // AccessControl.sol doesn't revert if revoking permissions that haven't been granted
            // If we don't check, planner and executor can collude to gain access to contacts
            Permission memory _permission = _plan.permissions[_ids[i]]; 
            AccessControl contact = AccessControl(_permission.contact);
            bytes4 signature_ = _permission.signature;
            require(
                contact.hasRole(signature_, target),
                "Permission not found"
            );
            contact.revokeRole(signature_, target);
        }
        emit Executed(target);
    }

    /// @dev Restore the orchestration from an isolated target
    function restore(address target)
        external override auth
    {
        Plan storage _plan = plans[target];
        require(_plan.state == State.EXECUTED, "Emergency plan not executed.");
        _plan.state = State.PLANNED;
        
        bytes32[] memory _ids = _plan.ids;

        for (uint256 i = 0; i < _ids.length; i++){
            Permission memory permission_ = _plan.permissions[_ids[i]];
            AccessControl contact = AccessControl(permission_.contact);
            bytes4 signature_ = permission_.signature;
            contact.grantRole(signature_, target);
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

    /// @dev used to calculate the id of a Permission so it can be indexed within a Plan
    /// @param permission a permission, containing a contact address and a function signature
    function permissionToId(Permission memory permission)
        external pure returns(bytes32 id)
    {
        id = _permissionToId(permission);
    }

    /// @dev used to recreate a Permission from it's id
    /// @param id the key used for indexing a Permission within a Plan
    function idToPermission(bytes32 id)
        external pure returns(Permission memory permission) 
    {
        permission = _idToPermission(id);
    }

    function _permissionToId(Permission memory permission) 
        internal pure returns(bytes32 id) 
    {
        id = (bytes32(permission.signature) >> 160 | bytes32(bytes20(permission.contact)));
    }

    function _idToPermission(bytes32 id) 
        internal pure returns(Permission memory permission)
    {
        address contact = address(bytes20(id));
        bytes4 signature = bytes4(id << 160);
        permission = Permission(contact, signature);
    }
}