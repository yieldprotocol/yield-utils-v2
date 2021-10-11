// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";


/// @dev AuthEtherFaucet allowes privileged users to distribute Ether stored in this contract.
contract AuthEtherFaucet is AccessControl {
    event Sent(address indexed to, uint256 amount);

    constructor(address[] memory operators) AccessControl() {
        for (uint256 i = 0; i < operators.length; i++)
            _grantRole(AuthEtherFaucet.drip.selector, operators[i]);
    }

    receive() external payable {}

    function drip(address payable to, uint256 amount)
        external
        auth
    {
        (bool sent,) = to.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit Sent(to, amount);
    }
}