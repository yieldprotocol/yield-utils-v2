// SPDX-License-Identifier: MIT
// Inspired on TimeLock.sol from Compound.
// Special thanks to BoringSolidity for his feedback.

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "./RevertMsgExtractor.sol";
import "./IsContract.sol";

interface ITimelock {
    function setDelay(uint32 delay_) external;
    function schedule(address[] calldata targets, bytes[] calldata data) external returns (bytes32 txHash);
    function scheduleRepeated(address[] calldata targets, bytes[] calldata data, uint256 salt) external returns (bytes32 txHash);
    function approve(bytes32 txHash) external;
    function execute(address[] calldata targets, bytes[] calldata data) external returns (bytes[] calldata results);
    function executeRepeated(address[] calldata targets, bytes[] calldata data, uint256 salt) external returns (bytes[] calldata results);
}

contract Timelock is ITimelock, AccessControl {
    using IsContract for address;

    enum STATE { UNSCHEDULED, SCHEDULED, APPROVED }

    struct Transaction {
        STATE state;
        uint32 eta;
    }

    uint32 public constant GRACE_PERIOD = 14 days;
    uint32 public constant MINIMUM_DELAY = 2 days;
    uint32 public constant MAXIMUM_DELAY = 30 days;

    event DelaySet(uint256 indexed delay);
    event Scheduled(bytes32 indexed txHash, address[] targets, bytes[] data);
    event Approved(bytes32 indexed txHash, uint32 eta);
    event Executed(bytes32 indexed txHash, address[] targets, bytes[] data);

    uint32 public delay;
    mapping (bytes32 => Transaction) public transactions;

    constructor(address governor) AccessControl() {
        delay = 0; // delay is set to zero initially to allow testing and configuration. Set to a different value to go live.

        _grantRole(ITimelock.schedule.selector, governor); // On going live, it is recommended the schedule permission is granted to chosen individuals
        _grantRole(ITimelock.scheduleRepeated.selector, governor); // On going live, it is recommended the schedule permission is granted to chosen individuals
        _grantRole(ITimelock.approve.selector, governor); // On going live, it is recommended the approve permission is kept for the sole use of the governor
        _grantRole(ITimelock.execute.selector, governor); // On going live, it is recommended the schedule permission is granted to chosen individuals
        _grantRole(ITimelock.executeRepeated.selector, governor); // On going live, it is recommended the schedule permission is granted to chosen individuals

        // Changing the delay must now be executed through this TimeLock contract
        _grantRole(ITimelock.setDelay.selector, address(this)); // bytes4(keccak256("setDelay(uint256)"))

        // Granting roles (schedule, cancel, execute, setDelay) must now be executed through this TimeLock contract
        _grantRole(ROOT, address(this));
        _revokeRole(ROOT, msg.sender);
    }

    /// @dev Change the delay for queueing and executing transactions
    function setDelay(uint32 delay_) external override auth {
        require(delay_ >= MINIMUM_DELAY, "Must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Must not exceed maximum delay.");
        delay = delay_;

        emit DelaySet(delay_);
    }

    /// @dev Schedule a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    function schedule(address[] calldata targets, bytes[] calldata data)
        external override auth returns (bytes32 txHash)
    {
        return _schedule(targets, data, 0);
    }

    /// @dev Schedule a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    /// @param salt Unique identifier for the transaction when repeatedly scheduled. Chosen by scheduler.
    function scheduleRepeated(address[] calldata targets, bytes[] calldata data, uint256 salt)
        external override auth returns (bytes32 txHash)
    {
        return _schedule(targets, data, salt);
    }

    /// @dev Schedule a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    function _schedule(address[] calldata targets, bytes[] calldata data, uint256 salt)
        private auth returns (bytes32 txHash)
    {
        require(targets.length == data.length, "Mismatched inputs");
        txHash = keccak256(abi.encode(targets, data, salt));
        require(transactions[txHash].state == STATE.UNSCHEDULED, "Transaction already scheduled.");
        transactions[txHash].state = STATE.SCHEDULED;
        emit Scheduled(txHash, targets, data);
    }

    /// @dev Cancel a scheduled transaction batch
    function approve(bytes32 txHash)
        external override auth
    {
        Transaction memory transaction = transactions[txHash];
        require(transaction.state == STATE.SCHEDULED, "Transaction not scheduled.");
        transaction.state = STATE.APPROVED;
        transaction.eta == uint32(block.timestamp) + delay;
        transactions[txHash] = transaction;
        emit Approved(txHash, transaction.eta);
    }

    /// @dev Execute a transaction batch
    function execute(address[] calldata targets, bytes[] calldata data)
        external override auth returns (bytes[] memory results)
    {
        return _execute(targets, data, 0);
    }
    
    /// @dev Execute a transaction batch
    /// @param salt Unique identifier for the transaction when repeatedly scheduled. Chosen by scheduler.
    function executeRepeated(address[] calldata targets, bytes[] calldata data, uint256 salt)
        external override auth returns (bytes[] memory results)
    {
        return _execute(targets, data, salt);
    }

    /// @dev Execute a transaction batch
    function _execute(address[] calldata targets, bytes[] calldata data, uint256 salt)
        private auth returns (bytes[] memory results)
    {
        bytes32 txHash = keccak256(abi.encode(targets, data, salt));
        Transaction memory transaction = transactions[txHash];
        require(transaction.state == STATE.APPROVED, "Transaction not approved.");

        require(uint32(block.timestamp) >= transaction.eta, "ETA not reached.");
        require(uint32(block.timestamp) <= transaction.eta + GRACE_PERIOD, "Transaction is stale.");

        delete transactions[txHash];

        results = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++){
            require(targets[i].isContract(), "Call to a non-contract");
            (bool success, bytes memory result) = targets[i].call(data[i]);
            if (!success) revert(RevertMsgExtractor.getRevertMsg(result));
            results[i] = result;
        }
        emit Executed(txHash, targets, data);
    }
}