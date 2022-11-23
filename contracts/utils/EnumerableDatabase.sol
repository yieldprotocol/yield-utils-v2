// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "./EnumerableSet.sol";


/// @dev This contract allows to maintain permissioned lists of data.
contract EnumerableDatabase is AccessControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    mapping(string => EnumerableSet.Bytes32Set) internal _data;

    function add(string memory id, bytes32 value) public auth returns (bool) {
        require (!_data[id].contains(value));
        return _data[id].add(value);
    }
    function replace(string memory id, bytes32 value) public auth returns (bool) {
        return _data[id].add(value);
    }
    function remove(string memory id, bytes32 value) public auth returns (bool) {
        return _data[id].remove(value);
    }
    function contains(string memory id, bytes32 value) public view returns (bool) {
        return _data[id].contains(value);
    }
    function length(string memory id) public view returns (uint) {
        return _data[id].length();
    }
    function at(string memory id, uint index) public view returns (bytes32) {
        return _data[id].at(index);
    }
    function values(string memory id) public view returns (bytes32[] memory) {
        return _data[id].values();
    }
}