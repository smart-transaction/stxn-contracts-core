// SPDX-License-Identifier: MIT
pragma solidity >=0.8.8 <0.9.0;

import "./Basics.sol";

/**
 * @dev Stores the first 4-bytes of the data along with its length. Uses 8-bytes total and can be
 * packed along with other values into a struct. First 4-bytes store the first 4-bytes of the actual
 * data and the remaining 4-bytes store the length.
 */
type compactCdHead is uint64;

/**
 * @dev Place holder struct to ensure library is using unique storage slot for data, will be
 * allocated a full 32-byte slot, make sure to place at the end of a struct to allow Solidity
 * to pack smaller data types. Make sure to a define a unique different tail pointer object for
 * every compact bytes you want to use.
 */
struct compactCdTailSlot {
    uint256 ___mass;
}

using CompactBytesLib for compactCdHead global;
using CompactBytesLib for compactCdTailSlot global;

/// @author philogy <https://github.com/philogy>
library CompactBytesLib {
    uint256 internal constant HEAD_CHUNK_MASK = 0xffffffff; // 4-byte mask
    uint256 internal constant HEAD_MASK = 0xffffffffffffffff;
    uint256 internal constant HEAD_BYTES_OFFSET_IN_DATA = 4;

    uint256 internal constant MAX_DATA_BYTES_LEN = HEAD_CHUNK_MASK;

    uint256 internal constant LEN_BITS_OFFSET = 32;

    function length(compactCdHead head) internal pure returns (uint256 len) {
        assembly {
            len := and(shl(LEN_BITS_OFFSET, head), HEAD_CHUNK_MASK)
        }
    }

    function store(compactCdTailSlot storage tailPtr, bytes memory data) internal returns (compactCdHead newHead) {
        /// @solidity memory-safe-assembly
        assembly {
            newHead := and(mload(add(data, HEAD_BYTES_OFFSET_IN_DATA)), HEAD_MASK)

            // Compute unique storage slot for extra data to go in (following Solidity's conventions).
            mstore(0x00, tailPtr.slot)
            let dataSlot := keccak256(0x00, 0x20)

            let len := mload(data)
            let offset := add(data, add(DATA_LEN_BYTES, HEAD_BYTES_OFFSET_IN_DATA))
            let endOffset := add(add(data, DATA_LEN_BYTES), len)

            for {} lt(offset, endOffset) { offset := add(offset, WORD_SIZE) } {
                sstore(dataSlot, mload(offset))
                dataSlot := add(dataSlot, 1)
            }
        }
    }

    function load(compactCdHead head, compactCdTailSlot storage tailPtr) internal view returns (bytes memory data) {
        /// @solidity memory-safe-assembly
        assembly {
            data := mload(0x40)
            mstore(data, 0)
            mstore(add(data, HEAD_BYTES_OFFSET_IN_DATA), and(HEAD_MASK, head))

            mstore(0x00, tailPtr.slot)
            let dataSlot := keccak256(0x00, 0x20)

            let len := mload(data)
            let offset := add(data, add(DATA_LEN_BYTES, HEAD_BYTES_OFFSET_IN_DATA))
            let endOffset := add(add(data, DATA_LEN_BYTES), len)

            for {} lt(offset, endOffset) { offset := add(offset, WORD_SIZE) } {
                mstore(offset, sload(dataSlot))
                dataSlot := add(dataSlot, 1)
            }

            mstore(0x40, endOffset)
        }
    }
}
