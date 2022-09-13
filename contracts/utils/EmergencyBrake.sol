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
        Permission[] permissions;
        mapping(bytes32 => uint256) index; ///mapping of bytes32(signature) => position in permissions
    }

    event Planned(address indexed target, Permission[] permissions);
    event AddedTo(address indexed target, Permission toAdd);
    event RemovedFrom(address indexed target, Permission toRemove);
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
    function plan(address target, Permission[] calldata permissions)
        external override auth
    {
        require(plans[target].state == State.UNPLANNED, "Emergency already planned for.");
        // Removing or granting ROOT permissions is out of bounds for EmergencyBrake
        for (uint256 i = 0; i < permissions.length;){
            require(
                permissions[i].signature != ROOT,
                "Can't remove ROOT"
            );
            
            plans[target].permissions.push(permissions[i]);
            bytes32 toIndex = _persmissionToId(permissions[i].contact, permissions[i].signature);
            unchecked{++i;}
            plans[target].index[toIndex] = i;
        }
        plans[target].state = State.PLANNED;
        emit Planned(target, permissions);
    }

    /// @dev add a permission set to remove for a contact to an existing plan
    /// @dev a contact can be added multiple times to a plan but ensures that all signatures are unique to prevent revert on execution
    /// @param target address with auth privileges on a contract and a plan exists for
    /// @param toAdd permission set that is being added to an existing plan
    function addToPlan(address target, Permission calldata toAdd)
        external override auth 
    {   
        require(plans[target].state == State.PLANNED, "Target not planned for");
        require(toAdd.signature != ROOT, "Can't remove ROOT");
        Permission[] memory _permissions = plans[target].permissions;
        bytes32 toIndex = _persmissionToId(toAdd.contact, toAdd.signature);
        require(plans[target].index[toIndex] == 0, "Permission set already in plan");
        uint256 planId = _permissions.length;
        plans[target].permissions.push(toAdd);
        plans[target].index[toIndex] = planId;
        
        emit AddedTo(target, toAdd);
    }

    /// @dev remove a permission set from an existing plan
    /// @dev retains the order of permissions and updates their index
    /// @param target address wuth auth privileges on a contract and a plan exists for
    function removeFromPlan(address target, Permission calldata toRemove) 
        external override auth
    {   
        require(plans[target].state == State.PLANNED, "Target not planned for");
        Permission[] memory _permissions = plans[target].permissions;
        bytes32 idToRemove = _persmissionToId(toRemove.contact, toRemove.signature); 
        uint256 indexToReplace = plans[target].index[idToRemove];
        require(indexToReplace > 0, "Permission set not planned");
        --indexToReplace;
        uint256 replacement = _permissions.length - 1;
        bytes32 idToReindex = _persmissionToId(_permissions[replacement].contact, _permissions[replacement].signature);
        plans[target].permissions[indexToReplace] = _permissions[replacement];
        plans[target].index[idToRemove] = 0;
        plans[target].index[idToReindex] = indexToReplace;
        plans[target].permissions.pop();
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
        require(plans[target].state == State.PLANNED, "Emergency not planned for.");
        plans[target].state = State.EXECUTED;

        Permission[] memory permissions_ = plans[target].permissions;

        for (uint256 i = 0; i < permissions_.length; i++){
            // AccessControl.sol doesn't revert if revoking permissions that haven't been granted
            // If we don't check, planner and executor can collude to gain access to contacts
            Permission memory permission_ = permissions_[i]; 
            AccessControl contact = AccessControl(permission_.contact);
            bytes4 signature_ = permission_.signature;
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
        require(plans[target].state == State.EXECUTED, "Emergency plan not executed.");
        plans[target].state = State.PLANNED;

        Permission[] memory permissions_ = plans[target].permissions;

        for (uint256 i = 0; i < permissions_.length; i++){
            Permission memory permission_ = permissions_[i]; 
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
    /// @param contact the address for a contract
    /// @param signature the auth signature of a function within contact
    function permissionToId(address contact, bytes4 signature)
        external pure returns(bytes32 id)
    {
        id = _persmissionToId(contact, signature);
    }

    /// @dev used to recreate a Permission from it's id
    /// @param id the key used for indexing a Permission within a Plan
    function idToPermission(bytes32 id)
        external pure returns(Permission memory permission) 
    {
        permission = _idToPermission(id);
    }

    function _persmissionToId(address contact, bytes4 signature) 
        internal pure returns(bytes32 id) 
    {
        id = (bytes32(signature) >> 160 | bytes32(bytes20(contact)));
    }

    function _idToPermission(bytes32 id) 
        internal pure returns(Permission memory permission)
    {
        address contact = address(bytes20(id));
        bytes4 signature = bytes4(id << 160);
        permission = Permission(contact, signature);
    }
}