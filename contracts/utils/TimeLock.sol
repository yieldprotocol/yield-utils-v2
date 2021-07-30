// SPDX-License-Identifier: MIT
// Inspired on TimeLock.sol from Compound.

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "./RevertMsgExtractor.sol";

interface ITimeLock {
    function setDelay(uint32 delay_) external;
    function queue(address[] memory targets, bytes[] memory data, uint32 eta) external returns (bytes32 txHash);
    function cancel(address[] memory targets, bytes[] memory data, uint32 eta) external;
    function execute(address[] memory targets, bytes[] memory data, uint32 eta) external returns (bytes[] memory results);
}

contract TimeLock is ITimeLock, AccessControl {
    uint32 public constant GRACE_PERIOD = 14 days;
    uint32 public constant MINIMUM_DELAY = 2 days;
    uint32 public constant MAXIMUM_DELAY = 30 days;

    event DelaySet(uint32 indexed delay);
    event Cancelled(bytes32 indexed txHash, address[] indexed targets, bytes[] data, uint32 eta);
    event Executed(bytes32 indexed txHash, address[] indexed targets, bytes[] data, uint32 eta);
    event Queued(bytes32 indexed txHash, address[] indexed targets, bytes[] data, uint32 eta);

    uint32 public delay;
    mapping (bytes32 => bool) public queued;

    constructor() AccessControl() {
        delay = MINIMUM_DELAY;

        // msg.sender can queue, cancel, and execute transactions
        _grantRole(ITimeLock.queue.selector, msg.sender); // bytes4(keccak256("queue(address[],bytes[],uint32)"))
        _grantRole(ITimeLock.cancel.selector, msg.sender); // bytes4(keccak256("cancel(address[],bytes[],uint32)"))
        _grantRole(ITimeLock.execute.selector, msg.sender); // bytes4(keccak256("execute(address[],bytes[],uint32)"))

        // Changing the delay must now be executed through this TimeLock contract
        _grantRole(ITimeLock.setDelay.selector, address(this)); // bytes4(keccak256("setDelay(uint32)"))

        // Granting roles (queue, cancel, execute, setDelay) must now be executed through this TimeLock contract
        _grantRole(ROOT, address(this));
        _revokeRole(ROOT, msg.sender);
    }

    /// @dev Change the delay for queueing and executing transactions
    function setDelay(uint32 delay_) external override auth {
        require(delay_ >= MINIMUM_DELAY, "Must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Must not exceed maximum delay.");
        delay = delay_;

        emit DelaySet(delay);
    }

    /// @dev Schedule a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    function queue(address[] memory targets, bytes[] memory data, uint32 eta)
        external override auth returns (bytes32 txHash)
    {
        require(targets.length == data.length, "Mismatched inputs");
        require(eta >= uint32(block.timestamp) + delay, "Must satisfy delay.");
        
        txHash = keccak256(abi.encode(targets, data, eta));
        queued[txHash] = true;
        emit Queued(txHash, targets, data, eta);
    }

    /// @dev Cancel a scheduled  transaction batch
    function cancel(address[] memory targets, bytes[] memory data, uint32 eta)
        external override auth
    {
        require(targets.length == data.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(targets, data, eta));
        queued[txHash] = false;
        emit Cancelled(txHash, targets, data, eta);
    }

    /// @dev Execute a transaction batch
    function execute(address[] memory targets, bytes[] memory data, uint32 eta)
        external override auth returns (bytes[] memory results)
    {
        require(targets.length == data.length, "Mismatched inputs");
        require(uint32(block.timestamp) >= eta, "ETA not reached.");
        require(uint32(block.timestamp) <= eta + GRACE_PERIOD, "Transaction is stale.");
        bytes32 txHash = keccak256(abi.encode(targets, data, eta));
        require(queued[txHash] == true, "Transaction hasn't been queued.");
        queued[txHash] = false;

        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++){
            (bool success, bytes memory result) = targets[i].call(data[i]);
            if (!success) revert(RevertMsgExtractor.getRevertMsg(result));
            results[i] = result;
            emit Executed(txHash, targets, data, eta);
        }
    }
}