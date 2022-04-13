// SPDX-License-Identifier: MIT
// Inspired on Timelock.sol from Compound.
// Special thanks to BoringCrypto and Mudit Gupta for their feedback.

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "./RevertMsgExtractor.sol";
import "./IsContract.sol";


interface IOptimisticTimelock {
    struct Call {
        address target;
        bytes data;
    }

    function setDelay(uint32 delay_) external;
    function schedule(Call[] calldata functionCalls) external returns (bytes32 txHash, uint32 eta);
    function scheduleRepeated(Call[] calldata functionCalls, uint256 salt) external returns (bytes32 txHash, uint32 eta);
    function deny(bytes32 txHash) external;
    function execute(Call[] calldata functionCalls) external returns (bytes[] calldata results);
    function executeRepeated(Call[] calldata functionCalls, uint256 salt) external returns (bytes[] calldata results);
}

/// @dev With the OptimisticTimelock, all proposals are automatically approved, but an account with `deny`
/// permissions can take them off the queue.
/// @notice In the event of a DoS attack, simply take the `schedule` permissions from the atacker.
contract OptimisticTimelock is IOptimisticTimelock, AccessControl {
    using IsContract for address;

    enum STATE { UNKNOWN, SCHEDULED, DENIED }

    struct Proposal {
        STATE state;
        uint32 eta;
    }

    uint32 public constant GRACE_PERIOD = 14 days;
    uint32 public constant MINIMUM_DELAY = 2 days;
    uint32 public constant MAXIMUM_DELAY = 30 days;

    event DelaySet(uint256 indexed delay);
    event Proposed(bytes32 indexed txHash, uint32 eta);
    event Denied(bytes32 indexed txHash);
    event Executed(bytes32 indexed txHash);

    uint32 public delay;
    mapping (bytes32 => Proposal) public proposals;

    constructor(address governor) AccessControl() {
        delay = 0; // delay is set to zero initially to allow testing and configuration. Set to a different value to go live.

        // Each role in AccessControl.sol is a 1-of-n multisig. It is recommended that trusted individual accounts get `schedule`
        // and `execute` permissions, while only the governor keeps `deny` permissions. The governor should keep the `schedule`
        // and `execute` permissions, but use them only in emergency situations (such as all trusted individuals going rogue).
        _grantRole(IOptimisticTimelock.schedule.selector, governor);
        _grantRole(IOptimisticTimelock.scheduleRepeated.selector, governor);
        _grantRole(IOptimisticTimelock.deny.selector, governor);
        _grantRole(IOptimisticTimelock.execute.selector, governor);
        _grantRole(IOptimisticTimelock.executeRepeated.selector, governor);

        // Changing the delay must now be executed through this Timelock contract
        _grantRole(IOptimisticTimelock.setDelay.selector, address(this)); // bytes4(keccak256("setDelay(uint256)"))

        // Granting roles (schedule, deny, execute, setDelay) must now be executed through this Timelock contract
        // For increased security, ROOT can be given to a non-optimistic Timelock and removed from `this`.
        _grantRole(ROOT, address(this));
        _revokeRole(ROOT, msg.sender);
    }

    /// @dev Change the delay for denyd proposals
    function setDelay(uint32 delay_) external override auth {
        require(delay_ >= MINIMUM_DELAY, "Must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Must not exceed maximum delay.");
        delay = delay_;

        emit DelaySet(delay_);
    }

    /// @dev Propose a transaction batch for execution
    function schedule(Call[] calldata functionCalls)
        external override auth returns (bytes32 txHash, uint32 eta)
    {
        return _schedule(functionCalls, 0);
    }

    /// @dev Propose a transaction batch for execution, with other identical proposals existing
    /// @param salt Unique identifier for the transaction when repeatedly scheduled. Chosen by governor.
    function scheduleRepeated(Call[] calldata functionCalls, uint256 salt)
        external override auth returns (bytes32 txHash, uint32 eta)
    {
        return _schedule(functionCalls, salt);
    }

    /// @dev Propose a transaction batch for execution
    function _schedule(Call[] calldata functionCalls, uint256 salt)
        private returns (bytes32 txHash, uint32 eta)
    {
        txHash = keccak256(abi.encode(functionCalls, salt));
        require(proposals[txHash].state == STATE.UNKNOWN, "Already scheduled.");
        eta = uint32(block.timestamp) + delay;
        proposals[txHash] = Proposal({
            state: STATE.SCHEDULED,
            eta: eta
        });
        emit Proposed(txHash, eta);
    }

    /// @dev Approve a proposal and set its eta
    function deny(bytes32 txHash)
        external override auth
    {
        Proposal memory proposal = proposals[txHash];
        require(proposal.state == STATE.SCHEDULED, "Not scheduled.");
        proposals[txHash].state = STATE.DENIED;
        emit Denied(txHash);
    }

    /// @dev Execute a proposal
    function execute(Call[] calldata functionCalls)
        external override auth returns (bytes[] memory results)
    {
        return _execute(functionCalls, 0);
    }
    
    /// @dev Execute a proposal, among several identical ones
    /// @param salt Unique identifier for the transaction when repeatedly scheduled. Chosen by governor.
    function executeRepeated(Call[] calldata functionCalls, uint256 salt)
        external override auth returns (bytes[] memory results)
    {
        return _execute(functionCalls, salt);
    }

    /// @dev Execute a proposal
    function _execute(Call[] calldata functionCalls, uint256 salt)
        private returns (bytes[] memory results)
    {
        bytes32 txHash = keccak256(abi.encode(functionCalls, salt));
        Proposal memory proposal = proposals[txHash];

        require(proposal.state == STATE.SCHEDULED, "Not denyd.");
        require(uint32(block.timestamp) >= proposal.eta, "ETA not reached.");
        require(uint32(block.timestamp) <= proposal.eta + GRACE_PERIOD, "Proposal is stale.");

        delete proposals[txHash];

        results = new bytes[](functionCalls.length);
        for (uint256 i = 0; i < functionCalls.length; i++){
            require(functionCalls[i].target.isContract(), "Call to a non-contract");
            (bool success, bytes memory result) = functionCalls[i].target.call(functionCalls[i].data);
            if (!success) revert(RevertMsgExtractor.getRevertMsg(result));
            results[i] = result;
        }
        emit Executed(txHash);
    }
}