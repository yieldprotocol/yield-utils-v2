// SPDX-License-Identifier: MIT
// Inspired on TimeLock.sol from Compound.

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "./RevertMsgExtractor.sol";


contract TimeLock is AccessControl {
    uint32 public constant GRACE_PERIOD = 14 days;
    uint32 public constant MINIMUM_DELAY = 2 days;
    uint32 public constant MAXIMUM_DELAY = 30 days;

    event DelaySet(uint32 indexed delay);
    event TransactionCancelled(bytes32 indexed txHash, address indexed target, bytes data, uint256 index, uint256 length, uint32 eta);
    event TransactionExecuted(bytes32 indexed txHash, address indexed target, bytes data, uint256 index, uint256 length, uint32 eta);
    event TransactionQueued(bytes32 indexed txHash, address indexed target, bytes data, uint256 index, uint256 length, uint32 eta);

    uint32 public delay;
    mapping (bytes32 => bool) public queued;

    constructor() AccessControl() {
        delay = MINIMUM_DELAY;

        // msg.sender can queue, cancel, and execute transactions
        _grantRole(bytes4(keccak256("queue(address[],bytes[],uint32)")), msg.sender);
        _grantRole(bytes4(keccak256("cancel(address[],bytes[],uint32)")), msg.sender);
        _grantRole(bytes4(keccak256("execute(address[],bytes[],uint32)")), msg.sender);

        // Changing the delay must now be executed through this TimeLock contract
        _grantRole(bytes4(keccak256("setDelay(uint32)")), address(this));

        // Granting roles (queue, cancel, execute, setDelay) must now be executed through this TimeLock contract
        _grantRole(ROOT, address(this));
        _revokeRole(ROOT, msg.sender);
    }

    /// @dev Change the delay for queueing and executing transactions
    function setDelay(uint32 delay_) external auth {
        require(delay_ >= MINIMUM_DELAY, "Must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Must not exceed maximum delay.");
        delay = delay_;

        emit DelaySet(delay);
    }

    /// @dev Schedule a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    function queue(address[] memory targets, bytes[] memory data, uint32 eta)
        external auth returns (bytes32[] memory txHashes)
    {
        require(targets.length == data.length, "Mismatched inputs");
        require(eta >= uint32(block.timestamp) + delay, "Must satisfy delay.");

        txHashes = new bytes32[](targets.length);
        for (uint256 i = 0; i < targets.length; i++){
            bytes32 txHash = keccak256(abi.encode(targets[i], data[i], i, targets.length, eta));
            queued[txHash] = true;
            emit TransactionQueued(txHash, targets[i], data[i], i, targets.length, eta);
        }
    }

    /// @dev Cancel a scheduled  transaction batch
    function cancel(address[] memory targets, bytes[] memory data, uint32 eta)
        external auth
    {
        require(targets.length == data.length, "Mismatched inputs");
        for (uint256 i = 0; i < targets.length; i++){
            bytes32 txHash = keccak256(abi.encode(targets[i], data[i], i, targets.length, eta));
            queued[txHash] = false;
            emit TransactionCancelled(txHash, targets[i], data[i], i, targets.length, eta);
        }
    }

    /// @dev Execute a transaction batch
    function execute(address[] memory targets, bytes[] memory data, uint32 eta)
        external auth returns (bytes[] memory results)
    {
        require(targets.length == data.length, "Mismatched inputs");
        require(uint32(block.timestamp) >= eta, "Time lock not reached.");
        require(uint32(block.timestamp) <= eta + GRACE_PERIOD, "Transaction is stale.");

        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++){
            bytes32 txHash = keccak256(abi.encode(targets[i], data[i], i, targets.length, eta));
            require(queued[txHash] == true, "Transaction hasn't been queued.");
            (bool success, bytes memory result) = targets[i].call(data[i]);
            if (!success) revert(RevertMsgExtractor.getRevertMsg(result));
            results[i] = result;
            queued[txHash] = false;
            emit TransactionExecuted(txHash, targets[i], data[i], i, targets.length, eta);
        }
    }
}