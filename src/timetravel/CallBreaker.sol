// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./CallBreakerStorage.sol";

contract CallBreaker is CallBreakerStorage {
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
    /// @dev Error thrown when a nonexistent key is fetched from the associatedDataStore
    /// @dev Selector 0xf7c16a37
    error NonexistentKey();
    /// @dev Caller must be EOA
    /// @dev Selector 0x09d1095b
    error MustBeEOA();
    /// @dev Error thrown when the call position is not as expected
    /// @dev Selector 0xd2c5d316
    error CallPositionFailed(CallObject, uint256);

    /// @notice Emitted when the enterPortal function is called
    /// @param callObj The CallObject instance containing details of the call
    /// @param returnvalue The ReturnObject instance containing details of the return value
    /// @param index The index of the return value in the returnStore
    event EnterPortal(CallObject callObj, ReturnObject returnvalue, uint256 index);

    /// @notice Emitted when the verifyStxn function is called
    event VerifyStxn();

    event CallPopulated(CallObject callObj, uint256 index);

    /// @notice Initializes the contract; sets the initial portal status to closed
    constructor() {
        _setPortalClosed();
    }

    /// @dev Modifier to make a function callable only when the portal is open.
    ///      Reverts if the portal is closed. Portal is opened by `verify`.
    modifier ensureTurnerOpen() {
        if (!isPortalOpen()) {
            revert PortalClosed();
        }
        _;
    }

    /// @notice Verifies that the given calls, when executed, gives the correct return values
    /// @dev SECURITY NOTICE: This function is only callable when the portal is closed. It requires the caller to be an EOA.
    /// @param callsBytes The bytes representing the calls to be verified
    /// @param returnsBytes The bytes representing the returns to be verified against
    /// @param associatedData Bytes representing associated data with the verify call, reserved for tipping the solver
    function verify(
        bytes calldata callsBytes,
        bytes calldata returnsBytes,
        bytes calldata associatedData,
        bytes calldata hintdices
    ) external payable onlyPortalClosed {
        if (msg.sender.code.length != 0) {
            revert MustBeEOA();
        }
        _setPortalOpen();

        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory returnValues = abi.decode(returnsBytes, (ReturnObject[]));

        if (calls.length != returnValues.length) {
            revert LengthMismatch();
        }

        _resetTraceStoresWith(calls, returnValues);
        _populateAssociatedDataStore(associatedData);
        _populateHintdices(hintdices);
        _populateCallIndices();

        uint256 l = calls.length;
        for (uint256 i = 0; i < l; i++) {
            _setCurrentlyExecutingCallIndex(i);
            _executeAndVerifyCall(i);
        }

        _cleanUpStorage();
        _setPortalClosed();
        emit VerifyStxn();
    }

    /// @notice Executes a call and returns a value from the record of return values.
    /// @dev This function also does some accounting to track the occurrence of a given pair of call and return values.
    /// @param input The call to be executed, structured as a CallObjectWithIndex.
    /// @return The return value from the record of return values.
    function getReturnValue(bytes calldata input) external view returns (bytes memory) {
        // Decode the input to obtain the CallObject and calculate a unique ID representing the call-return pair
        CallObjectWithIndex memory callObjWithIndex = abi.decode(input, (CallObjectWithIndex));
        ReturnObject memory thisReturn = _getReturn(callObjWithIndex.index);
        return thisReturn.returnvalue;
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

    /// @notice Fetches the CallObject and ReturnObject at a given index from the callStore and returnStore respectively
    /// @param i The index at which the CallObject and ReturnObject are to be fetched
    /// @return A pair of CallObject and ReturnObject at the given index
    function getPair(uint256 i) public view returns (CallObject memory, ReturnObject memory) {
        return (callStore[i], returnStore[i]);
    }

    /// @notice Fetches the Call at a given index from the callList
    /// @param i The index at which the Call is to be fetched
    /// @return The Call at the given index
    function getCallListAt(uint256 i) public view returns (Call memory) {
        return callList[i];
    }

    /// very important to document this
    /// @notice Searches the callList for all indices of the callId
    /// @dev This is very gas-extensive as it computes in O(n)
    /// @param callObj The callObj to search for
    function getCompleteCallIndexList(CallObject calldata callObj) public view returns (uint256[] memory) {
        bytes32 callId = keccak256(abi.encode(callObj));
        uint256[] memory index = new uint256[](callList.length);
        for (uint256 i = 0; i < callList.length; i++) {
            if (callList[i].callId == callId) {
                index[i] = i;
            }
        }
        return index;
    }

    /// @notice Fetches the indices of a given CallObject from the hintdicesStore
    /// @dev This function validates that the correct callId lives at these hintdices
    /// @param callObj The CallObject whose indices are to be fetched
    /// @return An array of indices where the given CallObject is found
    function getCallIndex(CallObject calldata callObj) public view returns (uint256[] memory) {
        bytes32 callId = keccak256(abi.encode(callObj));
        // look up this callid in hintdices
        uint256[] storage hintdices = hintdicesStore[callId].indices;
        // validate that the right callid lives at these hintdices
        for (uint256 i = 0; i < hintdices.length; i++) {
            uint256 hintdex = hintdices[i];
            Call memory call = callList[hintdex];
            if (call.callId != callId) {
                revert CallPositionFailed(callObj, hintdex);
            }
        }
        return hintdices;
    }

    /// @notice Converts a reverse index into a forward index or vice versa
    /// @dev This function looks at the callstore and returnstore indices
    /// @param index The index to be converted
    /// @return The converted index
    function getReverseIndex(uint256 index) public view returns (uint256) {
        if (index >= callStore.length) {
            revert IndexMismatch(index, callStore.length);
        }
        return returnStore.length - index - 1;
    }

    /// @notice Fetches the currently executing call index
    /// @dev This function reverts if the portal is closed
    /// @return The currently executing call index
    function getCurrentlyExecuting() public view returns (uint256) {
        if (!isPortalOpen()) {
            revert PortalClosed();
        }
        return executingCallIndex();
    }

    function _populateCallIndices() internal {
        uint256 l = callStore.length;
        for (uint256 i = 0; i < l; i++) {
            Call memory call = Call({callId: keccak256(abi.encode(callStore[i])), index: i});
            callList.push(call);
            emit CallPopulated(callStore[i], i);
        }
    }

    /// @dev Executes a single call and verifies the result by generating the call-return pair ID
    /// @param i The index of the CallObject and returnobject to be executed and verified
    function _executeAndVerifyCall(uint256 i) internal {
        (CallObject memory callObj, ReturnObject memory retObj) = getPair(i);
        if (callObj.amount > address(this).balance) {
            revert OutOfEther();
        }

        emit EnterPortal(callObj, retObj, i);

        (bool success, bytes memory returnvalue) =
            callObj.addr.call{gas: callObj.gas, value: callObj.amount}(callObj.callvalue);
        if (!success) {
            revert CallFailed();
        }

        if (keccak256(retObj.returnvalue) != keccak256(returnvalue)) {
            revert CallVerificationFailed();
        }
    }

    /// @notice Populates the associatedDataStore with a list of key-value pairs
    /// @param encodedData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function _populateAssociatedDataStore(bytes memory encodedData) internal {
        // Decode the input data into an array of (bytes32, bytes32) pairs
        (bytes32[] memory keys, bytes[] memory values) = abi.decode(encodedData, (bytes32[], bytes[]));

        // Check that the keys and values arrays have the same length
        if (keys.length != values.length) {
            revert LengthMismatch();
        }

        uint256 l = keys.length;
        // Iterate over the keys and values arrays and insert each pair into the associatedDataStore
        for (uint256 i = 0; i < l; i++) {
            _insertIntoAssociatedDataStore(keys[i], values[i]);
        }
    }

    function _populateHintdices(bytes memory encodedData) internal {
        // Decode the input data into an array of (bytes32, bytes32) pairs
        (bytes32[] memory keys, uint256[] memory values) = abi.decode(encodedData, (bytes32[], uint256[]));

        // Check that the keys and values arrays have the same length
        if (keys.length != values.length) {
            revert LengthMismatch();
        }

        uint256 l = keys.length;
        // Iterate over the keys and values arrays and insert each pair into the hintdices
        for (uint256 i = 0; i < l; i++) {
            _insertIntoHintdices(keys[i], values[i]);
        }
    }

    function _expectCallAt(CallObject memory callObj, uint256 index) internal view {
        if (keccak256(abi.encode(callStore[index])) != keccak256(abi.encode(callObj))) {
            revert CallPositionFailed(callObj, index);
        }
    }
}
