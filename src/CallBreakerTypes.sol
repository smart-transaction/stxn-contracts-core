// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "./TimeTypes.sol";
import "./libraries/Basics.sol";

/// @dev Struct representing a ReturnObject with an associated index
/// @param returnObj The actual ReturnObject instance
/// @param index The index associated with the ReturnObject
struct ReturnObjectWithIndex {
    ReturnObject returnObj;
    uint256 index;
}

struct AssociatedDataStorage {
    uint256 _head;
}

/// @dev struct used to get flash loan through call breaker
/// @param provider of flash loan should be EIP 3165 complaint
/// @param token address of the token being loaned
/// @param amount to fetched as flash loan
struct FlashLoanData {
    address provider;
    address tokenA;
    uint256 amountA;
    address tokenB;
    uint256 amountB;
}

using AssociatedDataLib for AssociatedDataStorage global;

library AssociatedDataLib {
    uint256 internal constant SET_FLAG = 1 << 255;

    uint256 internal constant LENGTH_LARGE_THRESHOLD = 31;
    uint256 internal constant LENGTH_LARGE_FLAG_OFFSET = 254;
    uint256 internal constant LENGTH_LARGE_FLAG = 1 << 254;
    uint256 internal constant FLAG_BITS = 2;
    uint256 internal constant LENGHT_LARGE_OFFSET = 224;

    uint256 internal constant DATA_SMALL_PACKED_OFFSET = 31; // Only need 1 byte for the length

    uint256 internal constant DATA_LARGE_PACKED_OFFSET = 28; // Reserve 4 bytes for the length

    uint256 internal constant LARGE_DATA_SIZE_CAP = 0x40000000; // Up to 30 bits (4 bytes * 8 bits - 2 flags)

    error AssociatedDataLengthTooLarge();

    function set(AssociatedDataStorage storage assocDataStorage) internal view returns (bool) {
        return assocDataStorage._head & SET_FLAG != 0;
    }

    /**
     * @dev Packs byte-strings with length <=31 into one slot together with the necessary flags,
     * this allows storing associated data like addresses more efficiently.
     */
    function store(AssociatedDataStorage storage assocDataStorage, bytes memory value) internal {
        uint256 head = SET_FLAG;
        /// @solidity memory-safe-assembly
        assembly {
            let len := mload(value)

            switch gt(len, LENGTH_LARGE_THRESHOLD)
            case 0 { head := or(mload(add(value, DATA_SMALL_PACKED_OFFSET)), head) }
            default {
                if iszero(lt(len, LARGE_DATA_SIZE_CAP)) {
                    mstore(0x00, 0xece972c5 /* selector("AssociatedDataLengthTooLarge") */ )
                    revert(0x1c, 0x04)
                }
                head := or(LENGTH_LARGE_FLAG, head)
                head := or(mload(add(value, DATA_LARGE_PACKED_OFFSET)), head)

                mstore(0x00, assocDataStorage.slot)
                let dataSlot := keccak256(0x00, 0x20)

                let offset := add(value, DATA_LARGE_PACKED_OFFSET)
                let endOffset := add(add(value, DATA_LEN_BYTES), len)

                for {} lt(offset, endOffset) { offset := add(offset, WORD_SIZE) } {
                    sstore(dataSlot, mload(offset))
                    dataSlot := add(dataSlot, 1)
                }
            }
        }
        assocDataStorage._head = head;
    }

    function load(AssociatedDataStorage storage assocDataStorage) internal view returns (bytes memory data) {
        uint256 head = assocDataStorage._head;
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            mstore(data, 0)

            let packedData := shr(FLAG_BITS, shl(FLAG_BITS, head))

            switch and(head, LENGTH_LARGE_FLAG)
            case 0 { mstore(add(data, DATA_SMALL_PACKED_OFFSET), packedData) }
            default {
                mstore(add(data, DATA_LARGE_PACKED_OFFSET), packedData)
                mstore(0x00, assocDataStorage.slot)
                let dataSlot := keccak256(0x00, 0x20)

                let offset := add(data, DATA_LARGE_PACKED_OFFSET)
                let len := mload(data)
                let endOffset := add(add(data, DATA_LEN_BYTES), len)

                for {} lt(offset, endOffset) { offset := add(offset, WORD_SIZE) } {
                    mstore(offset, sload(dataSlot))
                    dataSlot := add(dataSlot, 1)
                }
            }

            let len := mload(data)
            mstore(0x40, add(add(data, DATA_LEN_BYTES), len))
        }
    }

    function wipe(AssociatedDataStorage storage assocDataStorage) internal {
        uint256 head = assocDataStorage._head;
        /// @solidity memory-safe-assembly
        assembly {
            let packedData := shr(FLAG_BITS, shl(FLAG_BITS, head))

            if and(head, LENGTH_LARGE_FLAG) {
                let len := shr(LENGHT_LARGE_OFFSET, packedData)

                mstore(0x00, assocDataStorage.slot)
                let dataSlot := keccak256(0x00, 0x20)

                let offset := DATA_LARGE_PACKED_OFFSET

                for {} lt(offset, len) { offset := add(offset, WORD_SIZE) } {
                    sstore(dataSlot, 0)
                    dataSlot := add(dataSlot, 1)
                }
            }
        }

        delete assocDataStorage._head;
    }
}

/// @dev Struct representing associated data
/// @param set Whether the associated data is set or not
/// @param value The value of the associated data
struct AssociatedData {
    bool set;
    bytes value;
}

/// @dev Struct representing a hintdex
/// @param set Whether the hintdex is set or not
/// @param indices The indices associated with the hintdex
struct Hintdex {
    bool set;
    uint256[] indices;
}

/// @dev Struct representing a Call
/// @param callId The ID of the call
/// @param index The index associated with the call
struct Call {
    bytes32 callId;
    uint256 index;
}

struct CallBalance {
    bool set;
    int256 balance;
}
