// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IAccessControl {
    struct RoleData {
        mapping (address => bool) members;
        bytes4 adminRole;
    }

    event RoleAdminChanged(bytes4 indexed role, bytes4 indexed newAdminRole);
    event RoleGranted(bytes4 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes4 indexed role, address indexed account, address indexed sender);

    function ROOT() external view returns (bytes4);
    function LOCK() external view returns (bytes4);
    function hasRole(bytes4 role, address account) external view returns (bool);
    function getRoleAdmin(bytes4 role) external view returns (bytes4);
    function setRoleAdmin(bytes4 role, bytes4 adminRole) external;
    function grantRole(bytes4 role, address account) external;
    function grantRoles(bytes4[] memory roles, address account) external;
    function lockRole(bytes4 role) external;
    function revokeRole(bytes4 role, address account) external;
    function revokeRoles(bytes4[] memory roles, address account) external;
    function renounceRole(bytes4 role, address account) external;
}