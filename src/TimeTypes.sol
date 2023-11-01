// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

/// @dev Struct for holding call object details
/// @param amount The amount of Ether to send with the call
/// @param addr The target address of the call
/// @param gas The gas limit for the call
/// @param callvalue The ABI-encoded data payload for the call
struct CallObject {
    uint256 amount;
    address addr;
    uint256 gas;
    bytes callvalue;
}

/// @dev Struct for holding a CallObject with an associated index
/// @param callObj The actual CallObject instance
/// @param index The index we expect to be associated with the CallObject
struct CallObjectWithIndex {
    CallObject callObj;
    uint256 index;
}

/// @dev Struct for holding return object details
/// @param returnvalue The ABI-encoded data payload returned from the call
struct ReturnObject {
    bytes returnvalue;
}

/// @dev Struct for holding a delegateable CallObject with additional metadata
/// @param initialized Flag indicating if the CallObject has been pushed as a deferred call
/// @param firstCallableBlock The first block where the CallObject is callable
/// @param callObj The actual CallObject instance
struct CallObjectHolder {
    bool initialized;
    uint256 firstCallableBlock;
    CallObject[] callObjs;
}
