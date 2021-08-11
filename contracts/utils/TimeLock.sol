// SPDX-License-Identifier: MIT
// Inspired on TimeLock.sol from Compound.

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "./RevertMsgExtractor.sol";

interface ITimeLock {
    function setDelay(uint256 delay_) external;
    function schedule(address[] memory targets, bytes[] memory data, uint256 eta) external returns (bytes32 txHash);
    function cancel(address[] memory targets, bytes[] memory data, uint256 eta) external;
    function execute(address[] memory targets, bytes[] memory data, uint256 eta) external returns (bytes[] memory results);
}

contract TimeLock is ITimeLock, AccessControl {
    enum State {UNKNOWN, SCHEDULED, CANCELLED, EXECUTED}

    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;

    event DelaySet(uint256 indexed delay);
    event Cancelled(bytes32 indexed txHash, address[] indexed targets, bytes[] data, uint256 eta);
    event Executed(bytes32 indexed txHash, address[] indexed targets, bytes[] data, uint256 eta);
    event Scheduled(bytes32 indexed txHash, address[] indexed targets, bytes[] data, uint256 eta);

    uint256 public delay;
    mapping (bytes32 => State) public transactions;

    constructor(address scheduler, address executor) AccessControl() {
        delay = MINIMUM_DELAY;

        // scheduler can schedule and cancel, executor can execute
        _grantRole(ITimeLock.schedule.selector, scheduler); // bytes4(keccak256("schedule(address[],bytes[],uint256)"))
        _grantRole(ITimeLock.cancel.selector, scheduler); // bytes4(keccak256("cancel(address[],bytes[],uint256)"))
        _grantRole(ITimeLock.execute.selector, executor); // bytes4(keccak256("execute(address[],bytes[],uint256)"))

        // Changing the delay must now be executed through this TimeLock contract
        _grantRole(ITimeLock.setDelay.selector, address(this)); // bytes4(keccak256("setDelay(uint256)"))

        // Granting roles (schedule, cancel, execute, setDelay) must now be executed through this TimeLock contract
        _grantRole(ROOT, address(this));
        _revokeRole(ROOT, msg.sender);
    }

    /// @dev Change the delay for queueing and executing transactions
    function setDelay(uint256 delay_) external override auth {
        require(delay_ >= MINIMUM_DELAY, "Must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Must not exceed maximum delay.");
        delay = delay_;

        emit DelaySet(delay);
    }

    /// @dev Schedule a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    function schedule(address[] memory targets, bytes[] memory data, uint256 eta)
        external override auth returns (bytes32 txHash)
    {
        require(targets.length == data.length, "Mismatched inputs");
        require(eta >= block.timestamp + delay, "Must satisfy delay.");
        txHash = keccak256(abi.encode(targets, data, eta));
        require(transactions[txHash] == State.UNKNOWN, "Transaction not unknown.");
        transactions[txHash] = State.SCHEDULED;
        emit Scheduled(txHash, targets, data, eta);
    }

    /// @dev Cancel a scheduled transaction batch
    function cancel(address[] memory targets, bytes[] memory data, uint256 eta)
        external override auth
    {
        require(targets.length == data.length, "Mismatched inputs");
        bytes32 txHash = keccak256(abi.encode(targets, data, eta));
        require(transactions[txHash] == State.SCHEDULED, "Transaction hasn't been scheduled.");
        transactions[txHash] = State.CANCELLED;
        emit Cancelled(txHash, targets, data, eta);
    }

    /// @dev Execute a transaction batch
    function execute(address[] memory targets, bytes[] memory data, uint256 eta)
        external override auth returns (bytes[] memory results)
    {
        require(targets.length == data.length, "Mismatched inputs");
        require(block.timestamp >= eta, "ETA not reached.");
        require(block.timestamp <= eta + GRACE_PERIOD, "Transaction is stale.");
        bytes32 txHash = keccak256(abi.encode(targets, data, eta));
        require(transactions[txHash] == State.SCHEDULED, "Transaction hasn't been scheduled.");
        transactions[txHash] = State.EXECUTED;

        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++){
            (bool success, bytes memory result) = targets[i].call(data[i]);
            if (!success) revert(RevertMsgExtractor.getRevertMsg(result));
            results[i] = result;
        }
        emit Executed(txHash, targets, data, eta);
    }
}