// SPDX-License-Identifier: MIT
// Inspired on Timelock.sol from Compound.
// Special thanks to BoringSolidity for his feedback.

pragma solidity ^0.8.0;
import "../access/AccessControl.sol";
import "./RevertMsgExtractor.sol";
import "./IsContract.sol";


interface ITimelock {
    function setDelay(uint32 delay_) external;
    function propose(address[] calldata targets, bytes[] calldata data) external returns (bytes32 txHash);
    function proposeRepeated(address[] calldata targets, bytes[] calldata data, uint256 salt) external returns (bytes32 txHash);
    function approve(bytes32 txHash) external returns (uint32);
    function execute(address[] calldata targets, bytes[] calldata data) external returns (bytes[] calldata results);
    function executeRepeated(address[] calldata targets, bytes[] calldata data, uint256 salt) external returns (bytes[] calldata results);
}

contract Timelock is ITimelock, AccessControl {
    using IsContract for address;

    enum STATE { UNKNOWN, PROPOSED, APPROVED }

    struct Proposal {
        STATE state;
        uint32 eta;
    }

    uint32 public constant GRACE_PERIOD = 14 days;
    uint32 public constant MINIMUM_DELAY = 2 days;
    uint32 public constant MAXIMUM_DELAY = 30 days;

    event DelaySet(uint256 indexed delay);
    event Proposed(bytes32 indexed txHash, address[] targets, bytes[] data);
    event Approved(bytes32 indexed txHash, uint32 eta);
    event Executed(bytes32 indexed txHash, address[] targets, bytes[] data);

    uint32 public delay;
    mapping (bytes32 => Proposal) public proposals;

    constructor(address governor) AccessControl() {
        delay = 0; // delay is set to zero initially to allow testing and configuration. Set to a different value to go live.

        _grantRole(ITimelock.propose.selector, governor);           // On going live, it is recommended the propose permission is granted to chosen individuals
        _grantRole(ITimelock.proposeRepeated.selector, governor);   // On going live, it is recommended the propose permission is granted to chosen individuals
        _grantRole(ITimelock.approve.selector, governor);           // On going live, it is recommended the approve permission is kept for the sole use of the governor
        _grantRole(ITimelock.execute.selector, governor);           // On going live, it is recommended the propose permission is granted to chosen individuals
        _grantRole(ITimelock.executeRepeated.selector, governor);   // On going live, it is recommended the propose permission is granted to chosen individuals

        // Changing the delay must now be executed through this Timelock contract
        _grantRole(ITimelock.setDelay.selector, address(this)); // bytes4(keccak256("setDelay(uint256)"))

        // Granting roles (propose, cancel, execute, setDelay) must now be executed through this Timelock contract
        _grantRole(ROOT, address(this));
        _revokeRole(ROOT, msg.sender);
    }

    /// @dev Change the delay for queueing and executing proposals
    function setDelay(uint32 delay_) external override auth {
        require(delay_ >= MINIMUM_DELAY, "Must exceed minimum delay.");
        require(delay_ <= MAXIMUM_DELAY, "Must not exceed maximum delay.");
        delay = delay_;

        emit DelaySet(delay_);
    }

    /// @dev Propose a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    function propose(address[] calldata targets, bytes[] calldata data)
        external override auth returns (bytes32 txHash)
    {
        return _propose(targets, data, 0);
    }

    /// @dev Propose a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    /// @param salt Unique identifier for the transaction when repeatedly proposed. Chosen by governor.
    function proposeRepeated(address[] calldata targets, bytes[] calldata data, uint256 salt)
        external override auth returns (bytes32 txHash)
    {
        return _propose(targets, data, salt);
    }

    /// @dev Propose a transaction batch for execution between `eta` and `eta + GRACE_PERIOD`
    function _propose(address[] calldata targets, bytes[] calldata data, uint256 salt)
        private auth returns (bytes32 txHash)
    {
        require(targets.length == data.length, "Mismatched inputs");
        txHash = keccak256(abi.encode(targets, data, salt));
        require(proposals[txHash].state == STATE.UNKNOWN, "Already proposed.");
        proposals[txHash].state = STATE.PROPOSED;
        emit Proposed(txHash, targets, data);
    }

    /// @dev Cancel a proposed transaction batch
    function approve(bytes32 txHash)
        external override auth returns (uint32 eta)
    {
        Proposal memory proposal = proposals[txHash];
        require(proposal.state == STATE.PROPOSED, "Not proposed.");
        eta = uint32(block.timestamp) + delay;
        proposal.state = STATE.APPROVED;
        proposal.eta = eta;
        proposals[txHash] = proposal;
        emit Approved(txHash, eta);
    }

    /// @dev Execute a transaction batch
    function execute(address[] calldata targets, bytes[] calldata data)
        external override auth returns (bytes[] memory results)
    {
        return _execute(targets, data, 0);
    }
    
    /// @dev Execute a transaction batch
    /// @param salt Unique identifier for the transaction when repeatedly proposed. Chosen by governor.
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
        Proposal memory proposal = proposals[txHash];

        require(proposal.state == STATE.APPROVED, "Not approved.");
        require(uint32(block.timestamp) >= proposal.eta, "ETA not reached.");
        require(uint32(block.timestamp) <= proposal.eta + GRACE_PERIOD, "Proposal is stale.");

        delete proposals[txHash];

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