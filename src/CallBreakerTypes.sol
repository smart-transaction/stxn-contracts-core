// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "./TimeTypes.sol";

/// @dev Struct representing a ReturnObject with an associated index
/// @param returnObj The actual ReturnObject instance
/// @param index The index associated with the ReturnObject
struct ReturnObjectWithIndex {
    ReturnObject returnObj;
    uint256 index;
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
