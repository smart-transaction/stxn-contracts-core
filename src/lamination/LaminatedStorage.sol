// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../interfaces/ILaminator.sol";

abstract contract LaminatedStorage {
    /// @notice The slot at which the Laminator address is stored
    bytes32 public constant LAMINATOR_SLOT = bytes32(uint256(keccak256("LaminatorStorage.LAMINATOR_SLOT")) - 1);
    /// @notice The slot at which the owner address is stored
    bytes32 public constant OWNER_SLOT = bytes32(uint256(keccak256("LaminatorStorage.OWNER_SLOT")) - 1);
    /// @notice The slot at which the sequence number is stored
    bytes32 public constant SEQUENCE_NUMBER_SLOT = bytes32(uint256(keccak256("LaminatorStorage.SEQUENCE_NUMBER")) - 1);

    /// @dev Indicates that the owner or laminator has already been set and cannot be set again.
    /// @dev Selector 0xef34ca5c
    error AlreadyInit();

    /// @dev Cannot set Laminator to null address
    /// @dev Selector 0x9c89a95b
    error NullLaminator();

    /// @dev Cannot set Owner to null address
    /// @dev Selector 0xc77a0100
    error NullOwner();

    /// @notice Get Laminator contract
    function laminator() public view returns (ILaminator _laminator) {
        uint256 slot = uint256(LAMINATOR_SLOT);
        assembly ("memory-safe") {
            _laminator := sload(slot)
        }
    }

    /// @notice Get owner address
    function owner() public view returns (address _owner) {
        uint256 slot = uint256(OWNER_SLOT);
        assembly ("memory-safe") {
            _owner := sload(slot)
        }
    }

    /// @notice Get the number of calls in the mempool.
    /// @dev This is an alias for nextSequenceNumber(). It allows clearer code when
    ///      reading from the contract.
    /// @return _count The sequence number of the next call pushed to the laminated mempool.
    function count() public view returns (uint256 _count) {
        return nextSequenceNumber();
    }

    /// @notice Get the next message sequence number.
    /// @return _sequenceNumber The next message sequence number.
    function nextSequenceNumber() public view returns (uint256 _sequenceNumber) {
        uint256 slot = uint256(SEQUENCE_NUMBER_SLOT);
        assembly ("memory-safe") {
            _sequenceNumber := sload(slot)
        }
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
    /// @custom:reverts AlreadyInit() when owner has already been initialized.
    /// @custom:reverts NullOwner() when owner is the null address.
    function _setOwner(address _owner) internal {
        if (owner() != address(0)) {
            revert AlreadyInit();
        }
        if (_owner == address(0)) {
            revert NullOwner();
        }
        uint256 slot = uint256(OWNER_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _owner)
        }
    }

    /// @notice Set the laminator address
    /// @dev This function is called once during initialization.
    /// @param _laminator The address of the contract's laminator.
    /// @custom:reverts AlreadyInit() when laminator has already been initialized.
    /// @custom:reverts NullOwner() when laminator is the null address.
    function _setLaminator(address _laminator) internal {
        if (address(laminator()) != address(0)) {
            revert AlreadyInit();
        }
        if (_laminator == address(0)) {
            revert NullLaminator();
        }
        uint256 slot = uint256(LAMINATOR_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _laminator)
        }
    }
}
