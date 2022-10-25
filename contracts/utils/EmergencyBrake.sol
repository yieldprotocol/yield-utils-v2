// SPDX-License-Identifier: MIT
// Audit: https://hackmd.io/@devtooligan/YieldEmergencyBrakeSecurityReview2022-10-11

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


interface IEmergencyBrake {
    struct Permission {
        address host; /// contract for which a user holds auth priviliges
        bytes4 signature;
    }

    function add(address user, Permission calldata permission) external;
    function remove(address user, Permission calldata permission) external;
    function cancel(address user) external;
    function execute(address user) external;
    function restore(address user) external;
    function terminate(address user) external;
}

/// @dev EmergencyBrake allows to plan for and execute transactions that remove access permissions for a user
/// contract. In an permissioned environment this can be used for pausing components.
/// All contracts in scope of emergency plans must grant ROOT permissions to EmergencyBrake. To mitigate the risk
/// of governance capture, EmergencyBrake has very limited functionality, being able only to revoke existing roles
/// and to restore previously revoked roles. Thus EmergencyBrake cannot grant permissions that weren't there in the 
/// first place. As an additional safeguard, EmergencyBrake cannot revoke or grant ROOT roles.
contract EmergencyBrake is AccessControl, IEmergencyBrake {

    struct Plan {
        bool executed;
        mapping(bytes32 => Permission) permissions;
        mapping(uint => bytes32) ids; // Manual implementation of a dynamic array. Ids are assigned incrementally and position zero contains the length.
    }

    event Added(address indexed user, Permission newPermission);
    event Removed(address indexed user, Permission permissionOut);
    event Executed(address indexed user);
    event Restored(address indexed user);

    mapping (address => Plan) public plans;

    constructor(address planner, address executor) AccessControl() {
        // TODO: Think about the permissions and what is best to give on deployment
        _grantRole(IEmergencyBrake.add.selector, planner);
        _grantRole(IEmergencyBrake.remove.selector, planner);
        _grantRole(IEmergencyBrake.cancel.selector, planner);
        _grantRole(IEmergencyBrake.execute.selector, executor);
        _grantRole(IEmergencyBrake.restore.selector, planner);
        _grantRole(IEmergencyBrake.terminate.selector, planner);
        // Granting roles (plan, cancel, execute, restore, terminate, modifyPlan) is reserved to ROOT
    }

    /// @dev Add permissions to an isolation scheme
    /// @dev a host can be added multiple times to a plan but ensures that all signatures are unique to prevent revert on execution
    /// @param user address with auth privileges on a contract and a plan exists for
    /// @param newPermission permission set that is being added to an existing plan
    function add(address user, Permission[] memory permissionsIn)
        external override auth 
    {   
        Plan storage plan_ = plans[user];
        require(!plan_.executed, "No changes while in execution");

        uint length = permissionsIn.length;
        for (uint i; i < length; ++i) {
            Permission memory permissionIn = permissionsIn[i];
            require(permissionIn.signature != ROOT, "Can't remove ROOT");
            bytes32 idIn = _permissionToId(permissionIn);
            require(plan_.permissions[idIn].signature == bytes4(0), "Permission already set");

            plan_.permissions[idIn] = permissionIn; // Set the permission
            uint idLength = uint(plan_.ids[0]) + 1;
            plan_.ids[idLength] = idIn; // Push the id
            plan_.ids[0] = idLength; // Update id array length
            
            emit Added(user, permissionIn);
        }

    }

    /// @dev Remove permissions from an isolation scheme
    /// @param user address with auth privileges on a contract and a plan exists for
    function remove(address user, Permission[] memory permissionsOut) 
        external override auth
    {   
        Plan storage plan_ = plans[user];
        require(!plan_.executed, "No changes while in execution");

        uint length = permissionsOut.length;
        for (uint i; i < length; ++i) {
            Permission memory permissionOut = permissionsOut[i];
            bytes32 idOut = _permissionToId(permissionOut);
            require(plan_.permissions[idOut].signature != bytes4(0), "Permission not found");

            delete plan_.permissions[idOut]; // Remove the permission
            
            // Loop through the ids array, copy the last item on top of the removed permission, then pop.
            uint idLength = plan_.ids[0];
            for (uint i = 1; i <= idLength; ++i ) {
                if (plan_.ids[i] == idOut) {
                    if (i < idLength) plan_.ids[i] = plan_.ids[idLength];
                    delete plan_.ids[idLength]; // Remove the id
                    plan_.ids[0] = idLength - 1; // Update id array length
                    break;
                }
            }

            emit Removed(user, permissionOut);
        }
    }

    /// @dev Remove a planned isolation scheme
    function cancel(address user)
        external override auth
    {
        Plan storage plan_ = plans[user];
        require(!plan_.executed, "No changes while in execution");

        _erase(user);
    }

    /// @dev Remove the restoring option from an isolated user
    function terminate(address user)
        external override auth
    {
        _erase(user);
    }

    /// @dev Remove all data related to an user
    function _erase(address user)
        internal
    {
        Plan storage plan_ = plans[user];
        require(!plan_.executed, "No changes while in execution");

        // Loop through the ids array, and remove everything.
        uint length = plan_.ids[0];
        for (uint i = 1; i <= length; ++i ) {
            emit PermissionRemoved(user, plan_.permissions[id);
            bytes32 id = plan_.ids[i];
            delete plan_.ids[i]; // Remove the id
            delete plan_.permissions[id]; // Remove the permission
        }
        delete plan_.ids[0]; // Set the array length to zero
        delete plan_; // Remove the plan
    }

    /// @dev Execute an access removal transaction
    function execute(address user)
        external override auth
    {
        Plan storage plan_ = plans[user];
        require(!plan.executed, "Already executed");
        plan_.execute = true;

        Permission[] memory permissions_ = plan_.permissions;

        // Loop through the ids array, and revoke all roles.
        uint length = plan_.ids[0];
        for (uint i = 1; i <= length; ++i ) {
            bytes32 id = plan_.ids[i];
            Permission memory permission_ = permissions_[id]; 
            AccessControl host = AccessControl(permission_.host);
            bytes4 signature_ = permission_.signature;
            require(
                host.hasRole(signature_, user),
                "Permission not found"
            );
            host.revokeRole(signature_, user);
        }

        emit Executed(user);
    }

    /// @dev Restore the orchestration from an isolated user
    function restore(address user)
        external override auth
    {
        Plan storage plan_ = plans[user];
        require(plan_.executed, "Plan not executed");
        plan_.execute = false;

        Permission[] memory permissions_ = plan_.permissions;

        // Loop through the ids array, and grant all roles.
        uint length = plan_.ids[0];
        for (uint i = 1; i <= length; ++i ) {
            bytes32 id = plan_.ids[i];
            Permission memory permission_ = permissions_[id]; 
            AccessControl host = AccessControl(permission_.host);
            bytes4 signature_ = permission_.signature;
            host.grantRole(signature_, user);
        }

        emit Restored(user);
    }



    /// @dev used to calculate the id of a Permission so it can be indexed within a Plan
    /// @param permission a permission, containing a host address and a function signature
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
        id = bytes32(abi.encodePacked(permission.signature, permission.contact));
    }

    function _idToPermission(bytes32 id) 
        internal pure returns(Permission memory permission)
    {
        address host = address(bytes20(id));
        bytes4 signature = bytes4(id << 160);
        permission = Permission(host, signature);
    }
}