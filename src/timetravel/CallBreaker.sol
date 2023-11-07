// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./CallBreakerStorage.sol";

struct CallBalance {
    bool set;
    int256 balance;
}

struct ReturnObjectWithIndex {
    ReturnObject returnObj;
    uint256 index;
}

struct AssociatedData {
    bool set;
    bytes value;
}

contract CallBreaker is CallBreakerStorage {
    ReturnObjectWithIndex[] public returnStore;
    mapping(bytes32 => CallBalance) public callbalanceStore;
    bytes32[] public callbalanceKeyList;

    bytes32[] public associatedDataKeyList;
    mapping(bytes32 => AssociatedData) public associatedDataStore;

    /// @dev Error thrown when there are no return values left
    /// @dev Selector 0xc8acbe62
    error OutOfReturnValues();
    /// @dev Error thrown when there is not enough Ether left
    /// @dev Selector 0x75483b53
    error OutOfEther();
    /// @dev Error thrown when a call fails
    /// @dev Selector 0x3204506f
    error CallFailed();
    /// @dev Error thrown when call-return pairs don't have balanced counts
    /// @dev Selector 0x8489203a
    error TimeImbalance();
    /// @dev Error thrown when receiving empty calldata
    /// @dev Selector 0xc047a184
    error EmptyCalldata();
    /// @dev Error thrown when there is a length mismatch
    /// @dev Selector 0xff633a38
    error LengthMismatch();
    /// @dev Error thrown when call verification fails
    /// @dev Selector 0xcc68b8ba
    error CallVerificationFailed();
    /// @dev Error thrown when index of the callObj doesn't match the index of the returnObj
    /// @dev Selector 0xdba5f6f9
    error IndexMismatch(uint256, uint256);
    /// @dev Error thrown when key already exists in the associatedDataStore
    /// @dev Selector 0xaa1ba2f8
    error KeyAlreadyExists();
    /// @dev Error thrown when a nonexistent key is fetched from the associatedDataStore
    /// @dev Selector 0xf7c16a37
    error NonexistentKey();
    /// @dev Caller must be EOA
    /// @dev Selector 0x09d1095b
    error MustBeEOA();

    /// @notice Emitted when a new key-value pair is inserted into the associatedDataStore
    event InsertIntoAssociatedDataStore(bytes32 key, bytes value);

    /// @notice Emitted when a value is fetched from the associatedDataStore using a key
    event FetchFromAssociatedDataStore(bytes32 key);

    /// @notice Emitted when the enterPortal function is called
    /// @param callObj The CallObject instance containing details of the call
    /// @param returnvalue The ReturnObject instance containing details of the return value
    /// @param pairid The unique ID derived from the given callObj and returnvalue
    /// @param updatedcallbalance The updated balance of the call
    /// @param index The index of the return value in the returnStore
    event EnterPortal(
        CallObject callObj, ReturnObject returnvalue, bytes32 pairid, int256 updatedcallbalance, uint256 index
    );

    /// @notice Emitted when the verifyStxn function is called
    event VerifyStxn();

    /// @notice Initializes the contract; sets the initial portal status to closed
    constructor() {
        _setPortalClosed();
    }

    /// NOTE: Expect calls to arrive with non-null msg.data
    receive() external payable {
        revert EmptyCalldata();
    }

    /// NOTE: Expect calls to arrive with non-null msg.data
    /// NOTE: Calldata bytes are structured as a CallObject
    fallback(bytes calldata input) external payable returns (bytes memory) {
        (bytes memory portalInput, uint256 callIndex) = abi.decode(input, (bytes, uint256));
        return this.enterPortal(portalInput, callIndex);
    }

    /// @notice Fetches the value associated with a given key from the associatedDataStore
    /// @param key The key whose associated value is to be fetched
    /// @return The value associated with the given key
    function fetchFromAssociatedDataStore(bytes32 key) public view returns (bytes memory) {
        if (!associatedDataStore[key].set) {
            revert NonexistentKey();
        }
        return associatedDataStore[key].value;
    }

    /// @notice Generates a unique ID for a pair of CallObject and ReturnObject
    /// @param callObj The CallObject instance containing details of the call
    /// @param returnObj The ReturnObject instance containing details of the return value
    /// @return A unique ID derived from the given callObj and returnObj
    /// NOTE: This is used in `verify` to check that the return value is actually the return value.
    function getCallReturnID(CallObject memory callObj, ReturnObject memory returnObj) public pure returns (bytes32) {
        // Use keccak256 to generate a unique ID for a pair of CallObject and ReturnObject.
        return keccak256(abi.encode(callObj, returnObj));
    }

    /// @notice Executes a call and returns a value from the record of return values.
    /// @dev This function also does some accounting to track the occurrence of a given pair of call and return values.
    /// It is called as reentrancy in order to balance the calls of the solution and make things validate.
    /// @param input The call to be executed, structured as a CallObject.
    /// @param callIndex The index of the callObj used to enforce call order.
    /// @return The return value from the record of return values.
    function enterPortal(bytes calldata input, uint256 callIndex) external payable onlyPortalOpen returns (bytes memory) {
        // Ensure there's at least one return value available
        if (returnStore.length == 0) {
            revert OutOfReturnValues();
        }

        ReturnObjectWithIndex memory lastReturn = _popLastReturn();

        // Decode the input to obtain the CallObject and calculate a unique ID representing the call-return pair
        CallObjectWithIndex memory callObjWithIndex = abi.decode(input, (CallObjectWithIndex));

        // Check that the index of the callObj matches the index of the returnObj
        if (callObjWithIndex.index != lastReturn.index) {
            revert IndexMismatch(callObjWithIndex.index, lastReturn.index);
        }
        bytes32 pairID = getCallReturnID(callObjWithIndex.callObj, lastReturn.returnObj);

        // Update or initialize the balance of the call-return pair
        _incrementCallBalance(pairID);

        emit EnterPortal(
            callObjWithIndex.callObj,
            lastReturn.returnObj,
            pairID,
            callbalanceStore[pairID].balance,
            callObjWithIndex.index
        );
        return lastReturn.returnObj.returnvalue;
    }

    /// @notice Verifies that the given calls, when executed, gives the correct return values
    /// @dev SECURITY NOTICE: This function is only callable when the portal is closed. It requires the caller to be an EOA.
    /// @param callsBytes The bytes representing the calls to be verified
    /// @param returnsBytes The bytes representing the returns to be verified against
    /// @param associatedData Bytes representing associated data with the verify call, reserved for tipping the solver
    function verify(bytes memory callsBytes, bytes memory returnsBytes, bytes memory associatedData)
        external
        payable
        onlyPortalClosed
    {
        if (msg.sender.code.length != 0) {
            revert MustBeEOA();
        }

        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory returnValues = abi.decode(returnsBytes, (ReturnObject[]));

        if (calls.length != returnValues.length) {
            revert LengthMismatch();
        }

        _resetReturnStoreWith(returnValues);
        _populateAssociatedDataStore(associatedData);

        for (uint256 i = 0; i < calls.length; i++) {
            _executeAndVerifyCall(calls[i]);
        }

        _ensureAllPairsAreBalanced();

        _cleanUpStorage();

        // Transfer remaining ETH balance to the block builder
        address payable blockBuilder = payable(block.coinbase);
        emit VerifyStxn();
        blockBuilder.transfer(address(this).balance);
    }

    /// @dev Resets the returnStore with the given ReturnObject array
    /// @param returnValues The array of ReturnObject to reset the returnStore with
    function _resetReturnStoreWith(ReturnObject[] memory returnValues) internal {
        delete returnStore;
        for (uint256 i = 0; i < returnValues.length; i++) {
            ReturnObjectWithIndex memory returnObjWithIndex = ReturnObjectWithIndex({returnObj: returnValues[i], index: i});
            returnStore.push(returnObjWithIndex);
        }
    }

    /// @dev Executes a single call and verifies the result by generating the call-return pair ID
    /// @param callObj The CallObject to be executed and verified
    function _executeAndVerifyCall(CallObject memory callObj) internal {
        if (callObj.amount > address(this).balance) {
            revert OutOfEther();
        }

        (bool success, bytes memory returnvalue) =
            callObj.addr.call{gas: callObj.gas, value: callObj.amount}(callObj.callvalue);
        if (!success) {
            revert CallFailed();
        }

        bytes32 pairID = getCallReturnID(callObj, ReturnObject(returnvalue));
        _decrementCallBalance(pairID);
    }

    /// @dev Cleans up storage by resetting returnStore and callbalanceKeyList
    function _cleanUpStorage() internal {
        delete returnStore;
        delete callbalanceKeyList;
        for (uint256 i = 0; i < associatedDataKeyList.length; i++) {
            delete associatedDataStore[associatedDataKeyList[i]];
        }
        delete associatedDataKeyList;
    }

    // @dev Helper function to fetch and remove the last ReturnObject from the storage
    function _popLastReturn() internal returns (ReturnObjectWithIndex memory) {
        ReturnObjectWithIndex memory lastReturn = returnStore[returnStore.length - 1];
        returnStore.pop();
        return lastReturn;
    }

    /// @dev Helper function to increment the balance of a call-return pair in the storage.
    /// @param pairID The unique identifier for a call-return pair.
    function _incrementCallBalance(bytes32 pairID) internal {
        if (!callbalanceStore[pairID].set) {
            callbalanceStore[pairID].balance = 1;
            callbalanceKeyList.push(pairID);
            callbalanceStore[pairID].set = true;
        } else {
            callbalanceStore[pairID].balance++;
        }
    }

    /// @dev Helper function to decrement the balance of a call-return pair in the storage.
    /// @param pairID The unique identifier for a call-return pair.
    function _decrementCallBalance(bytes32 pairID) internal {
        if (!callbalanceStore[pairID].set) {
            callbalanceStore[pairID].balance = -1;
            callbalanceKeyList.push(pairID);
            callbalanceStore[pairID].set = true;
        } else {
            callbalanceStore[pairID].balance--;
        }
    }

    /// @notice Inserts a pair of bytes32 into the associatedDataStore and associatedDataKeyList
    /// @param key The key to be inserted into the associatedDataStore
    /// @param value The value to be associated with the key in the associatedDataStore
    function _insertIntoAssociatedDataStore(bytes32 key, bytes memory value) internal {
        // Check if the key already exists in the associatedDataStore
        if (associatedDataStore[key].set) {
            revert KeyAlreadyExists();
        }

        emit InsertIntoAssociatedDataStore(key, value);
        // Insert the key-value pair into the associatedDataStore
        associatedDataStore[key].set = true;
        associatedDataStore[key].value = value;

        // Add the key to the associatedDataKeyList
        associatedDataKeyList.push(key);
    }

    /// @notice Populates the associatedDataStore with a list of key-value pairs
    /// @param encodedData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function _populateAssociatedDataStore(bytes memory encodedData) internal {
        // Decode the input data into an array of (bytes32, bytes32) pairs
        (bytes32[] memory keys, bytes[] memory values) = abi.decode(encodedData, (bytes32[], bytes[]));

        // Check that the keys and values arrays have the same length
        require(keys.length == values.length, "Mismatch in keys and values array lengths");

        // Iterate over the keys and values arrays and insert each pair into the associatedDataStore
        for (uint256 i = 0; i < keys.length; i++) {
            _insertIntoAssociatedDataStore(keys[i], values[i]);
        }
    }

    /// @dev Ensures all call-return pairs have balanced counts.
    function _ensureAllPairsAreBalanced() internal view {
        for (uint256 i = 0; i < callbalanceKeyList.length; i++) {
            if (callbalanceStore[callbalanceKeyList[i]].balance != 0) {
                revert TimeImbalance();
            }
        }
    }

    function _getIndexFromEnd(CallObject[] memory callObjects, uint256 indexFromStart) internal pure returns (uint256) {
        return callObjects.length - indexFromStart - 1;
    }
}
