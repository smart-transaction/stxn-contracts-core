// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {compactCdHead, compactCdTailSlot} from "./libraries/CompactBytes.sol";
import {genericDynArrayHead, genericElementPtr, genericDynArrayElementsSlot} from "./libraries/CompactDynArray.sol";
import {SafeCast} from "openzeppelin/utils/math/SafeCast.sol";

enum DATATYPE {
    INT256,
    UINT256,
    STRING,
    ADDRESS,
    BYTES,
    BYTES32
}

/// @dev Struct for addtional info for the solver to use
/// @param name of the parameter
/// @param type of the parameter
/// @param value of parameter as string
struct SolverData {
    string name;
    DATATYPE datatype;
    string value;
}

/// @dev Struct for holding call object details
/// @param amount The amount of Ether to send with the call
/// @param addr The target address of the call
/// @param gas The gas limit for the call
/// @param callvalue The optional ABI-encoded data payload for the call
struct CallObject {
    uint256 amount;
    uint256 gas;
    address addr;
    bytes callvalue;
}

struct CallObjectStorage {
    uint32 flagAndGas;
    compactCdHead cdHead;
    address addr;
    uint256 amount;
    compactCdTailSlot cdTail;
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

/// @param initialized Flag indicating if the CallObject has been pushed as a deferred call
/// @param executed The first block where the CallObject is callable
/// @param none The first block where the CallObject is callable
/// @param firstCallableBlock The first block where the CallObject is callable
/// @param callObjs The list of call objs
/// @param data Additional info for the sequence of call objs
struct CallObjectHolder {
    bool initialized;
    bool executed;
    uint256 nonce;
    uint256 firstCallableBlock;
    CallObject[] callObjs;
    SolverData[] data;
}

struct CallObjectHolderStorage {
    bool initialized;
    bool executed;
    uint40 firstCallableBlock;
    uint256 executionNonce;
    genericDynArrayHead callObjsHead;
    genericDynArrayElementsSlot callObjsElements;
}

using CallObjectLib for CallObjectHolderStorage global;
using CallObjectLib for CallObjectStorage global;

library CallObjectLib {
    using SafeCast for uint256;

    error InvalidGas();

    uint256 internal constant MAX_PACKED_GAS = uint256(type(uint32).max) >> 1;
    uint256 internal constant AMOUNT_NON_ZERO_FLAG = uint256(1) << 31;
    uint256 internal constant GAS_MASK = 0x7fffffff;

    function store(CallObjectHolderStorage storage holderStorage, CallObjectHolder memory holder) internal {
        holderStorage.initialized = holder.initialized;
        holderStorage.executed = holder.executed;
        holderStorage.firstCallableBlock = holder.firstCallableBlock.toUint40();

        genericDynArrayHead callObjsHead;

        uint256 callObjsLength = holder.callObjs.length;
        for (uint256 i = 0; i < callObjsLength; i++) {
            genericElementPtr elementPtr;
            (callObjsHead, elementPtr) = callObjsHead.pushUnchecked(holderStorage.callObjsElements);
            toCallObjectFromPtr(elementPtr).store(holder.callObjs[i]);
        }

        holderStorage.callObjsHead = callObjsHead;
        holderStorage.executionNonce = holder.nonce;
    }

    function store(CallObjectStorage storage callObjStorage, CallObject memory callObj) internal {
        uint256 gas = callObj.gas;
        if (gas > MAX_PACKED_GAS) revert InvalidGas();
        uint256 amount = callObj.amount;
        if (amount == 0) {
            callObjStorage.flagAndGas = uint32(gas);
        } else {
            callObjStorage.flagAndGas = uint32(gas | AMOUNT_NON_ZERO_FLAG);
            callObjStorage.amount = amount;
        }

        callObjStorage.cdHead = callObjStorage.cdTail.store(callObj.callvalue);
        callObjStorage.addr = callObj.addr;
    }

    function load(CallObjectHolderStorage storage holderStorage)
        internal
        view
        returns (CallObjectHolder memory holder)
    {
        holder.initialized = holderStorage.initialized;
        holder.executed = holderStorage.executed;
        holder.firstCallableBlock = holderStorage.firstCallableBlock;
        uint256 len = holderStorage.callObjsHead.length();
        holder.callObjs = new CallObject[](len);

        for (uint256 i = 0; i < len; i++) {
            holder.callObjs[i] =
                toCallObjectFromPtr(holderStorage.callObjsHead.getUnchecked(holderStorage.callObjsElements, i)).load();
        }
    }

    function load(CallObjectStorage storage holderStorage) internal view returns (CallObject memory holder) {
        uint256 flagAndGas = holderStorage.flagAndGas;
        compactCdHead cdHead = holderStorage.cdHead;
        holder.addr = holderStorage.addr;

        if (flagAndGas & AMOUNT_NON_ZERO_FLAG == 0) {
            holder.gas = flagAndGas;
        } else {
            holder.gas = flagAndGas & GAS_MASK;
            holder.amount = holderStorage.amount;
        }

        holder.callvalue = cdHead.load(holderStorage.cdTail);
    }

    function getCallObj(CallObjectHolderStorage storage holder, uint256 index)
        internal
        view
        returns (CallObjectStorage storage)
    {
        return toCallObjectFromPtr(holder.callObjsHead.getUnchecked(holder.callObjsElements, index));
    }

    function toCallObjectFromPtr(genericElementPtr ptr) internal pure returns (CallObjectStorage storage callObj) {
        /// @solidity memory-safe-assembly
        assembly {
            callObj.slot := ptr
        }
    }
}
