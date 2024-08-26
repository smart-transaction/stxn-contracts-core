// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "../interfaces/ILaminator.sol";
import "../interfaces/ICallBreaker.sol";

abstract contract LaminatedStorage {
    /// @notice The slot at which the Laminator address is stored
    bytes32 public constant LAMINATOR_SLOT = bytes32(uint256(keccak256("LaminatorStorage.LAMINATOR_SLOT")) - 1);
    /// @notice The slot at which the CallBreaker address is stored
    bytes32 public constant CALL_BREAKER_SLOT = bytes32(uint256(keccak256("LaminatorStorage.CALL_BREAKER_SLOT")) - 1);
    /// @notice The slot at which the owner address is stored
    bytes32 public constant OWNER_SLOT = bytes32(uint256(keccak256("LaminatorStorage.OWNER_SLOT")) - 1);
    /// @notice The slot at which the sequence number is stored
    bytes32 public constant SEQUENCE_NUMBER_SLOT =
        bytes32(uint256(keccak256("LaminatorStorage.SEQUENCE_NUMBER_SLOT")) - 1);
    /// @notice The slot at which the current executing sequence number is stored
    /// @dev This is not to be confused with the SEQUENCE_NUMBER_SLOT, which tracks the sequence number of
    bytes32 public constant EXECUTING_SEQUENCE_NUMBER_SLOT =
        bytes32(uint256(keccak256("LaminatorStorage.EXEC_SEQ_NUM_SLOT")) - 1);
    /// @notice The slot at which the current executing call index is stored
    bytes32 public constant EXECUTING_CALL_INDEX_SLOT =
        bytes32(uint256(keccak256("LaminatorStorage.EXEC_CALL_INDEX_SLOT")) - 1);
    /// @notice The slot for checking whether or not a call is executing
    bytes32 public constant CALL_STATUS_SLOT = bytes32(uint256(keccak256("LaminatorStorage.CALL_STATUS_SLOT")) - 1);

    uint256 public executingNonce; // value used to cancel all pending transactions

    /// @notice The map from sequence number to calls held in the mempool.
    mapping(uint256 => CallObjectHolderStorage) internal _deferredCalls;

    function deferredCalls(uint256 index) public view returns (CallObjectHolder memory holder) {
        holder = _deferredCalls[index].load();
    }

    function cleanupLaminatorStorage(uint256[] memory seqNumbers) public {
        for (uint256 i = 0; i < seqNumbers.length; i++) {
            if (
                !_deferredCalls[seqNumbers[i]].executed
                    || (isCallExecuting() && seqNumbers[i] == executingSequenceNumber())
            ) {
                continue;
            }
            delete _deferredCalls[seqNumbers[i]];
        }
    }

    /// @notice Get Laminator contract
    function laminator() public view returns (ILaminator _laminator) {
        uint256 slot = uint256(LAMINATOR_SLOT);
        assembly ("memory-safe") {
            _laminator := sload(slot)
        }
    }

    /// @notice Get Laminator contract
    function callBreaker() public view returns (ICallBreaker _callBreaker) {
        uint256 slot = uint256(CALL_BREAKER_SLOT);
        assembly ("memory-safe") {
            _callBreaker := sload(slot)
        }
    }

    /// @notice Get owner address
    function owner() public view returns (address _owner) {
        uint256 slot = uint256(OWNER_SLOT);
        assembly ("memory-safe") {
            _owner := sload(slot)
        }
    }

    /// @notice Get the next message sequence number.
    /// @return _sequenceNumber The next message sequence number.
    function nextSequenceNumber() public view returns (uint256 _sequenceNumber) {
        uint256 slot = uint256(SEQUENCE_NUMBER_SLOT);
        assembly ("memory-safe") {
            _sequenceNumber := sload(slot)
        }
    }

    /// @notice Returns the sequence number of the currently executing call.
    /// @return _execSeqNum The sequence number of the currently executing call.
    function executingSequenceNumber() public view returns (uint256 _execSeqNum) {
        uint256 slot = uint256(EXECUTING_SEQUENCE_NUMBER_SLOT);
        assembly ("memory-safe") {
            _execSeqNum := sload(slot)
        }
    }

    /// @notice Returns the index number of the currently executing call.
    /// @return _execCallIndex The sequence number of the currently executing call.
    function executingCallIndex() public view returns (uint256 _execCallIndex) {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            _execCallIndex := sload(slot)
        }
    }

    /// @notice See whether or not a Laminator call is taking place
    /// @return _isExec Whether or not a call is executing in the laminator
    function isCallExecuting() public view returns (bool _isExec) {
        uint256 slot = uint256(CALL_STATUS_SLOT);
        assembly ("memory-safe") {
            _isExec := sload(slot)
        }
    }

    /// @notice Get the number of calls in the mempool.
    /// @dev This is an alias for nextSequenceNumber(). It allows clearer code when
    ///      reading from the contract.
    /// @return _count The sequence number of the next call pushed to the laminated mempool.
    function count() public view returns (uint256 _count) {
        return nextSequenceNumber();
    }

    /// @notice Get the next message sequence number, then increment it
    /// @dev This function is used when storing a call in the mempool (push).
    /// @return _sequenceNumber The next message sequence number.
    function _incrementSequenceNumber() internal returns (uint256 _sequenceNumber) {
        _sequenceNumber = nextSequenceNumber();
        uint256 slot = uint256(SEQUENCE_NUMBER_SLOT);
        assembly ("memory-safe") {
            sstore(slot, add(_sequenceNumber, 1))
        }
    }

    /// @notice Set the owner address
    /// @dev This function is called once during initialization.
    /// @param _owner The address of the contract's owner.
    function _setOwner(address _owner) internal {
        uint256 slot = uint256(OWNER_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _owner)
        }
    }

    /// @notice Set the laminator address
    /// @dev This function is called once during initialization.
    /// @param _laminator The address of the contract's laminator.
    function _setLaminator(address _laminator) internal {
        uint256 slot = uint256(LAMINATOR_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _laminator)
        }
    }

    /// @notice Set the laminator address
    /// @dev This function is called once during initialization.
    /// @param _callBreaker The address of the call breaker contract.
    function _setCallBreaker(address _callBreaker) internal {
        uint256 slot = uint256(CALL_BREAKER_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _callBreaker)
        }
    }

    /// @notice Sets the sequence number of the currently executing call.
    /// @dev This function should only be called while a call in deferredCalls is being executed.
    function _setCurrentlyExecutingSeqNum(uint256 _sequenceNumber) internal {
        uint256 slot = uint256(EXECUTING_SEQUENCE_NUMBER_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _sequenceNumber)
        }
    }

    /// @notice Sets the index of the currently executing call.
    /// @dev This function should only be called while a call in deferredCalls is being executed.
    function _setCurrentlyExecutingCallIndex(uint256 _callIndex) internal {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _callIndex)
        }
    }

    /// @notice Enter the Laminator executing environment
    /// @dev This is used in conjunction with modifiers that allow / disallow calls to be made based on whether or not a call is executing
    function _setExecuting() internal {
        uint256 slot = uint256(CALL_STATUS_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 1)
        }
    }

    /// @notice Exit the Laminator executing environment
    /// @dev This function should only be called while a call in deferredCalls is being executed.
    function _setFree() internal {
        uint256 slot = uint256(CALL_STATUS_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 0)
        }
    }
}
