// SPDX-License-Identifier: MIT
// Audit: https://hackmd.io/@devtooligan/YieldEmergencyBrakeSecurityReview2022-10-11

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "../interfaces/IEmergencyBrake.sol";


/// @dev EmergencyBrake allows to plan for and execute transactions that remove access permissions for a user
/// contract. In an permissioned environment this can be used for pausing components.
/// All contracts in scope of emergency plans must grant ROOT permissions to EmergencyBrake. To mitigate the risk
/// of governance capture, EmergencyBrake has very limited functionality, being able only to revoke existing roles
/// and to restore previously revoked roles. Thus EmergencyBrake cannot grant permissions that weren't there in the 
/// first place. As an additional safeguard, EmergencyBrake cannot revoke or grant ROOT roles.
contract EmergencyBrake is AccessControl, IEmergencyBrake {

    event Added(address indexed user, Permission permissionIn);
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
        // Granting roles (add, remove, cancel, execute, restore, terminate) is reserved to ROOT
    }

    /// @dev Is a plan executed?
    /// @param user address with auth privileges on permission hosts
    function executed(address user) external view returns (bool) {
        return plans[user].executed;
    }

    /// @dev Does a plan contain a permission?
    /// @param user address with auth privileges on permission hosts
    /// @param permission permission that is being queried about
    function contains(address user, Permission calldata permission) external view returns (bool) {
        return plans[user].permissions[_permissionToId(permission)].signature != bytes4(0);
    }

    /// @dev Index of a permission in a plan. Returns 0 if not present.
    /// @param user address with auth privileges on permission hosts
    /// @param permission permission that is being queried about
    function index(address user, Permission calldata permission) external view returns (uint) {
        Plan storage plan_ = plans[user];
        uint length = uint(plan_.ids[0]);
        require(length > 0, "Plan not found");

        bytes32 id = _permissionToId(permission);

        for (uint i = 1; i <= length; ++i ) {
            if (plan_.ids[i] == id) {
                return i;
            }
        }
        return 0;
    }

    /// @dev Number of permissions in a plan
    /// @param user address with auth privileges on permission hosts
    function total(address user) external view returns (uint) {
        return uint(plans[user].ids[0]);
    }

    /// @dev Add permissions to an isolation plan
    /// @param user address with auth privileges on permission hosts
    /// @param permissionsIn permissions that are being added to an existing plan
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
            plan_.ids[0] = bytes32(idLength); // Update id array length
            
            emit Added(user, permissionIn);
        }

    }

    /// @dev Remove permissions from an isolation plan
    /// @param user address with auth privileges on permission hosts
    /// @param permissionsOut permissions that are being removed from an existing plan
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
            uint idLength = uint(plan_.ids[0]);
            for (uint j = 1; j <= idLength; ++j ) {
                if (plan_.ids[j] == idOut) {
                    if (j < idLength) plan_.ids[j] = plan_.ids[idLength];
                    delete plan_.ids[idLength]; // Remove the id
                    plan_.ids[0] = bytes32(idLength - 1); // Update id array length
                    break;
                }
            }

            emit Removed(user, permissionOut);
        }
    }

    /// @dev Remove a planned isolation plan
    /// @param user address with an isolation plan
    function cancel(address user)
        external override auth
    {
        Plan storage plan_ = plans[user];
        require(!plan_.executed, "No changes while in execution");

        _erase(user);
    }

    /// @dev Remove the restoring option from an isolated user
    /// @param user address with an isolation plan
    function terminate(address user)
        external override auth
    {
        _erase(user);
    }

    /// @dev Remove all data related to an user
    /// @param user address with an isolation plan
    function _erase(address user)
        internal
    {
        Plan storage plan_ = plans[user];

        // Loop through the ids array, and remove everything.
        uint length = uint(plan_.ids[0]);
        require(length > 0, "Plan not found");

        for (uint i = 1; i <= length; ++i ) {
            bytes32 id = plan_.ids[i];
            emit Removed(user, plan_.permissions[id]);
            delete plan_.ids[i]; // Remove the id
            delete plan_.permissions[id]; // Remove the permission
        }
        delete plan_.ids[0]; // Set the array length to zero
    }

    /// @dev Execute an access removal transaction
    /// @param user address with an isolation plan
    function execute(address user)
        external override auth
    {
        Plan storage plan_ = plans[user];
        require(!plan_.executed, "Already executed");
        plan_.executed = true;

        // Loop through the ids array, and revoke all roles.
        uint length = uint(plan_.ids[0]);
        require(length > 0, "Plan not found");

        for (uint i = 1; i <= length; ++i ) {
            bytes32 id = plan_.ids[i];
            Permission memory permission_ = plan_.permissions[id]; 
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
        plan_.executed = false;

        // Loop through the ids array, and grant all roles.
        uint length = uint(plan_.ids[0]);
        require(length > 0, "Plan not found");

        for (uint i = 1; i <= length; ++i ) {
            bytes32 id = plan_.ids[i];
            Permission memory permission_ = plan_.permissions[id]; 
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
        id = bytes32(abi.encodePacked(permission.signature, permission.host));
    }

    function _idToPermission(bytes32 id) 
        internal pure returns(Permission memory permission)
    {
        address host = address(bytes20(id));
        bytes4 signature = bytes4(id << 160);
        permission = Permission(host, signature);
    }
}