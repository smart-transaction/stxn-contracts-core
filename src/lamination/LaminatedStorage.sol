// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../interfaces/ILaminator.sol";

abstract contract LaminatedStorage {
    bytes32 public constant LAMINATOR_SLOT = bytes32(uint256(keccak256("LaminatorStorage.LAMINATOR_SLOT")) - 1);
    bytes32 public constant OWNER_SLOT = bytes32(uint256(keccak256("LaminatorStorage.OWNER_SLOT")) - 1);

    error AlreadyInit();
    error NullLaminator();
    error NullOwner();

    function laminator() public view returns (ILaminator _laminator) {
        uint256 slot = uint256(LAMINATOR_SLOT);
        assembly ("memory-safe") {
            _laminator := sload(slot)
        }
    }

    function owner() public view returns (address _owner) {
        uint256 slot = uint256(OWNER_SLOT);
        assembly ("memory-safe") {
            _owner := sload(slot)
        }
    }

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