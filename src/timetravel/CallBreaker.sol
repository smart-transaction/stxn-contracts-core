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

    // @dev Selector 0xc8acbe62
    error OutOfReturnValues();
    // @dev Selector 0x75483b53
    error OutOfEther();
    // @dev Selector 0x3204506f
    error CallFailed();
    // @dev Selector 0x8489203a
    error TimeImbalance();
    // @dev Selector 0xc047a184
    error EmptyCalldata();
    // @dev Selector 0xff633a38
    error LengthMismatch();
    // @dev Selector 0xcc68b8ba
    error CallVerificationFailed();
    // @dev Selector ??????????
    error IndexMismatch(uint256, uint256);

    event InsertIntoAssociatedDataStore(bytes32 key, bytes value);
    event FetchFromAssociatedDataStore(bytes32 key);

    event EnterPortal(
        CallObject callObj, ReturnObject returnvalue, bytes32 pairid, int256 updatedcallbalance, uint256 index
    );
    event VerifyStxn();

    /// @notice Initializes the contract; sets the initial portal status to closed
    constructor() {
        _setPortalClosed();
    }

    /// NOTE: Expect calls to arrive with non-null msg.data
    receive() external payable {
        revert EmptyCalldata();
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

    /// @notice Inserts a pair of bytes32 into the associatedDataStore and associatedDataKeyList
    /// @param key The key to be inserted into the associatedDataStore
    /// @param value The value to be associated with the key in the associatedDataStore
    function insertIntoAssociatedDataStore(bytes32 key, bytes memory value) internal {
        // Check if the key already exists in the associatedDataStore
        require(!associatedDataStore[key].set, "Key already exists in the associatedDataStore");

        emit InsertIntoAssociatedDataStore(key, value);
        // Insert the key-value pair into the associatedDataStore
        associatedDataStore[key].set = true;
        associatedDataStore[key].value = value;

        // Add the key to the associatedDataKeyList
        associatedDataKeyList.push(key);
    }

    /// @notice Fetches the value associated with a given key from the associatedDataStore
    /// @param key The key whose associated value is to be fetched
    /// @return The value associated with the given key
    function fetchFromAssociatedDataStore(bytes32 key) public view returns (bytes memory) {
        AssociatedData memory associatedData = associatedDataStore[key];

        // Check if the key exists in the associatedDataStore
        require(associatedData.set, "Key does not exist in the associatedDataStore");

        // Return the value associated with the key
        return associatedData.value;
    }

    /// @notice Populates the associatedDataStore with a list of key-value pairs
    /// @param encodedData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function populateAssociatedDataStore(bytes memory encodedData) internal {
        // Decode the input data into an array of (bytes32, bytes32) pairs
        (bytes32[] memory keys, bytes[] memory values) = abi.decode(encodedData, (bytes32[], bytes[]));

        // Check that the keys and values arrays have the same length
        require(keys.length == values.length, "Mismatch in keys and values array lengths");

        // Iterate over the keys and values arrays and insert each pair into the associatedDataStore
        for (uint256 i = 0; i < keys.length; i++) {
            insertIntoAssociatedDataStore(keys[i], values[i]);
        }
    }

    /// NOTE: Expect calls to arrive with non-null msg.data
    /// NOTE: Calldata bytes are structured as a CallObject
    fallback(bytes calldata input) external payable returns (bytes memory) {
        return this.enterPortal(input);
    }

    /// this: takes in a call (structured as a CallObj), puts out a return value from the record of return values.
    /// also: does some accounting that we saw a given pair of call and return values once, and returns a thing off the emulated stack.
    /// called as reentrancy in order to balance the calls of the solution and make things validate.
    function enterPortal(bytes calldata input) external payable onlyPortalOpen returns (bytes memory) {
        // Ensure there's at least one return value available
        if (returnStore.length == 0) {
            revert OutOfReturnValues();
        }

        // Fetch and remove the last ReturnObject from storage
        ReturnObjectWithIndex memory lastReturn = popLastReturn();

        // Decode the input to obtain the CallObject and calculate a unique ID representing the call-return pair
        CallObjectWithIndex memory callObjWithIndex = abi.decode(input, (CallObjectWithIndex));

        // Check that the index of the callObj matches the index of the returnObj
        if (callObjWithIndex.index != lastReturn.index) {
            revert IndexMismatch(callObjWithIndex.index, lastReturn.index);
        }
        bytes32 pairID = getCallReturnID(callObjWithIndex.callObj, lastReturn.returnObj);

        // Update or initialize the balance of the call-return pair
        incrementCallBalance(pairID);

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
    function verify(bytes memory callsBytes, bytes memory returnsBytes, bytes memory associatedData)
        external
        payable
        onlyPortalClosed
    {
        // pretty sure the first check isn't necessary?
        //require(tx.origin == msg.sender, "Caller must be an EOA");
        require(msg.sender.code.length == 0, "msg.sender must be an EOA");

        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory return_s = abi.decode(returnsBytes, (ReturnObject[]));

        if (calls.length != return_s.length) {
            revert LengthMismatch();
        }

        resetReturnStoreWith(return_s);
        populateAssociatedDataStore(associatedData);

        for (uint256 i = 0; i < calls.length; i++) {
            executeAndVerifyCall(calls[i]);
        }

        ensureAllPairsAreBalanced();

        cleanUpStorage();

        // Transfer remaining ETH balance to the block builder
        address payable blockBuilder = payable(block.coinbase);
        emit VerifyStxn();
        blockBuilder.transfer(address(this).balance);
    }

    /// @dev Resets the returnStore with the given ReturnObject array
    function resetReturnStoreWith(ReturnObject[] memory return_s) internal {
        delete returnStore;
        for (uint256 i = 0; i < return_s.length; i++) {
            ReturnObjectWithIndex memory returnObjWithIndex = ReturnObjectWithIndex({returnObj: return_s[i], index: i});
            returnStore.push(returnObjWithIndex);
        }
    }

    /// @dev Executes a single call and verifies the result by generating the call-return pair ID
    function executeAndVerifyCall(CallObject memory callObj) internal {
        if (callObj.amount > address(this).balance) {
            revert OutOfEther();
        }

        (bool success, bytes memory returnvalue) =
            callObj.addr.call{gas: callObj.gas, value: callObj.amount}(callObj.callvalue);
        if (!success) {
            revert CallFailed();
        }

        bytes32 pairID = getCallReturnID(callObj, ReturnObject(returnvalue));
        decrementCallBalance(pairID);
    }

    /// @dev Cleans up storage by resetting returnStore and callbalanceKeyList
    function cleanUpStorage() internal {
        delete returnStore;
        delete callbalanceKeyList;
        for (uint256 i = 0; i < associatedDataKeyList.length; i++) {
            delete associatedDataStore[associatedDataKeyList[i]];
        }
        delete associatedDataKeyList;
    }

    // Helper function to fetch and remove the last ReturnObject from the storage
    function popLastReturn() internal returns (ReturnObjectWithIndex memory) {
        ReturnObjectWithIndex memory lastReturn = returnStore[returnStore.length - 1];
        returnStore.pop();
        return lastReturn;
    }

    /// @dev Helper function to increment the balance of a call-return pair in the storage.
    /// @param pairID The unique identifier for a call-return pair.
    function incrementCallBalance(bytes32 pairID) internal {
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
    ///
    function decrementCallBalance(bytes32 pairID) internal {
        if (!callbalanceStore[pairID].set) {
            callbalanceStore[pairID].balance = -1;
            callbalanceKeyList.push(pairID);
            callbalanceStore[pairID].set = true;
        } else {
            callbalanceStore[pairID].balance--;
        }
    }

    /// @dev Ensures all call-return pairs have balanced counts.
    function ensureAllPairsAreBalanced() internal view {
        for (uint256 i = 0; i < callbalanceKeyList.length; i++) {
            if (callbalanceStore[callbalanceKeyList[i]].balance != 0) {
                revert TimeImbalance();
            }
        }
    }
}
