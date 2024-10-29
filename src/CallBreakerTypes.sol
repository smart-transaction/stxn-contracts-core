// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "./TimeTypes.sol";

/// @dev Struct representing a ReturnObject with an associated index
/// @param returnObj The actual ReturnObject instance
/// @param index The index associated with the ReturnObject
struct ReturnObjectWithIndex {
    ReturnObject returnObj;
    uint256 index;
}

/// @dev Struct representing a Call
/// @param callId The ID of the call
/// @param index The index associated with the call
struct Call {
    bytes32 callId;
    uint256 index;
}

struct AdditionalData {
    bytes32 key;
    bytes value;
}

/// @dev struct used to get flash loan through call breaker
/// @param provider of flash loan should be EIP 3165 complaint
/// @param amountA amount of first token
/// @param amountB amount of second token
struct FlashLoanData {
    address provider;
    uint256 amountA;
    uint256 amountB;
}
