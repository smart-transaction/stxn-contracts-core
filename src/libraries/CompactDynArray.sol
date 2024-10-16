// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

type genericDynArrayHead is uint32;

type genericElementPtr is uint256;

struct genericDynArrayElementsSlot {
    uint256 ___mass;
}

using CompactDynArray for genericDynArrayHead global;
using CompactDynArray for genericDynArrayElementsSlot global;

library CompactDynArray {
    uint256 internal constant DYN_ARRAY_HEAD_MASK = 0xffffffff;

    function length(genericDynArrayHead dynArray) internal pure returns (uint256 len) {
        /// @solidity memory-safe-assembly
        assembly {
            len := dynArray
        }
    }

    function getUnchecked(genericDynArrayHead, genericDynArrayElementsSlot storage slot, uint256 index)
        internal
        pure
        returns (genericElementPtr elementPtr)
    {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, index)
            mstore(0x20, slot.slot)
            elementPtr := keccak256(0x00, 0x40)
        }
    }

    function pushUnchecked(genericDynArrayHead dynArray, genericDynArrayElementsSlot storage slot)
        internal
        pure
        returns (genericDynArrayHead updatedDynArray, genericElementPtr newElementPtr)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let elementIndex := dynArray
            updatedDynArray := and(add(dynArray, 1), DYN_ARRAY_HEAD_MASK)
            mstore(0x00, elementIndex)
            mstore(0x20, slot.slot)
            newElementPtr := keccak256(0x00, 0x40)
        }
    }
}
