// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/TimeTypes.sol";
import "src/timetravel/CallBreakerStorage.sol";
import "src/interfaces/IFlashLoan.sol";
import {IERC20} from "test/utils/interfaces/IMintableERC20.sol";

contract CallBreaker is CallBreakerStorage {
    /// @dev Error thrown when there is not enough Ether left
    /// @dev Selector 0x75483b53
    error OutOfEther();
    /// @dev Error thrown when a call fails
    /// @dev Selector 0x3204506f
    error CallFailed();
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
    /// @dev Error thrown when the call position of the incoming call is not as expected.
    /// @dev Selector 0xd2c5d316
    error CallPositionFailed(CallObject, uint256);

    event Tip(address indexed from, address indexed to, uint256 amount);

    /// @notice Emitted when the verifyStxn function is called
    event VerifyStxn();

    event CallPopulated(CallObject callObj, uint256 index);

    /// @notice Will be removed after updating the flash loan logic
    event CallBreakerFlashFunds(address tokenA, uint256 amountA, address tokenB, uint256 amountB);

    /// @notice Initializes the contract; sets the initial portal status to closed
    constructor() {
        _setPortalClosed();
    }

    /// @dev Tips should be transferred from each LaminatorProxy to the solver via msg.value
    receive() external payable {
        bytes32 tipAddrKey = keccak256(abi.encodePacked("tipYourBartender"));
        bytes memory tipAddrBytes = fetchFromAssociatedDataStore(tipAddrKey);
        address tipAddr = address(bytes20(tipAddrBytes));
        emit Tip(msg.sender, tipAddr, msg.value);
        payable(tipAddr).transfer(msg.value);
    }

    /// @notice executes and verifies that the given calls, when executed, gives the correct return values
    /// @dev SECURITY NOTICE: This function is only callable when the portal is closed. It requires the caller to be an EOA.
    /// @param callsBytes The calls to be executed
    /// @param returnsBytes The returns to be compareed with return values from call obj execution
    /// @param associatedData To be used in the execute and verify call, also reserved for tipping the solver
    function executeAndVerify(
        CallObject[] calldata callsBytes,
        ReturnObject[] calldata returnsBytes,
        AdditionalData[] calldata associatedData
    ) external payable onlyPortalClosed {
        CallObject[] memory calls = _setupExecutionData(callsBytes, returnsBytes, associatedData);
        bytes memory data = abi.encode(calls);
        _executeAndVerifyCalls(data);
    }

    /// @notice fetches flash loan before executing and verifying call objects who might use the loaned amount
    /// @dev SECURITY NOTICE: This function is a temporary place holder for a nested call objects solution which is still under development
    /// TODO: Remove and replace with a generic version of nested call objects
    /// @param callObjs The calls to be executed
    /// @param returnsBytes The returns to be compareed with return values from call obj execution
    /// @param associatedData To be used in the execute and verify call, also reserved for tipping the solver
    /// @param flashLoanData with information about aquiring the flash loan
    function executeAndVerify(
        CallObject[] calldata callObjs,
        ReturnObject[] calldata returnsBytes,
        AdditionalData[] calldata associatedData,
        FlashLoanData calldata flashLoanData
    ) external payable onlyPortalClosed {
        _setupExecutionData(callObjs, returnsBytes, associatedData);
        bytes memory data = abi.encode(callObjs);
        IFlashLoan(flashLoanData.provider).flashLoan(address(this), flashLoanData.amountA, flashLoanData.amountB, data);
    }

    /**
     * @dev Receive a flash loan.
     * @param tokenA The first loan currency.
     * @param amountA The amount of tokens lent.
     * @param tokenB The second loan currency.
     * @param amountB The amount of tokens lent.
     * @param data The encoded calls to be executed
     * @return true if the function executed successfully
     */
    function onFlashLoan(
        address, /*initiator*/
        address tokenA,
        uint256 amountA,
        address tokenB,
        uint256 amountB,
        bytes memory data
    ) external onlyPortalOpen returns (bool) {
        emit CallBreakerFlashFunds(tokenA, amountA, tokenB, amountB);

        _executeAndVerifyCalls(data);
        IERC20(tokenA).approve(msg.sender, amountA);
        IERC20(tokenB).approve(msg.sender, amountB);
        return true;
    }

    /// @notice Returns a value from the record of return values from the callObject.
    /// @dev This function also does some accounting to track the occurrence of a given pair of call and return values.
    /// @param callObjWithIndex The call to be executed, structured as a CallObjectWithIndex.
    /// @return The return value from the record of return values.
    function getReturnValue(CallObjectWithIndex calldata callObjWithIndex) external view returns (bytes memory) {
        ReturnObject memory thisReturn = _getReturn(callObjWithIndex.index);
        return thisReturn.returnvalue;
    }

    /// @notice Gets a return value from the record of return values from the index number.
    /// @dev This function also does some accounting to track the occurrence of a given pair of call and return values.
    /// @param index The index of call to be executed.
    /// @return The return value from the record of return values.
    function getReturnValue(uint256 index) external view returns (bytes memory) {
        ReturnObject memory thisReturn = _getReturn(index);
        return thisReturn.returnvalue;
    }

    /// @notice Fetches the value associated with a given key from the associatedDataStore
    /// @param key The key whose associated value is to be fetched
    /// @return The value associated with the given key
    function fetchFromAssociatedDataStore(bytes32 key) public view returns (bytes memory) {
        return associatedDataStore[key];
    }

    /// @notice Fetches the CallObject and ReturnObject at a given index from the callStore and returnStore respectively
    /// @param i The index at which the CallObject and ReturnObject are to be fetched
    /// @return A pair of CallObject and ReturnObject at the given index
    function getPair(uint256 i) public view returns (CallObject memory, ReturnObject memory) {
        return (_getCall(i), returnStore[i]);
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
    function getCompleteCallIndexList(CallObject calldata callObj) external view returns (uint256[] memory) {
        bytes32 callId = keccak256(abi.encode(callObj));

        // First, determine the count of matching elements
        uint256 count;
        for (uint256 i; i < callList.length; i++) {
            if (callList[i].callId == callId) {
                count++;
            }
        }

        // Allocate the result array with the correct size
        uint256[] memory indexList = new uint256[](count);
        uint256 j;
        for (uint256 i; i < callList.length; i++) {
            if (callList[i].callId == callId) {
                indexList[j] = i;
                j++;
            }
        }
        return indexList;
    }

    /// @notice Fetches the indices of a given CallObject from the hintdicesStore
    /// @dev This function validates that the correct callId lives at these hintdices
    /// @param callObj The CallObject whose indices are to be fetched
    /// @return An array of indices where the given CallObject is found
    function getCallIndex(CallObject calldata callObj) public view returns (uint256[] memory) {
        bytes32 callId = keccak256(abi.encode(callObj));
        // look up this callid in hintdices
        uint256[] memory hintdices = hintdicesStore[callId];
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
    function getCurrentlyExecuting() public view onlyPortalOpen returns (uint256) {
        return _executingCallIndex();
    }

    function _setupExecutionData(
        CallObject[] calldata calls,
        ReturnObject[] calldata returnValues,
        AdditionalData[] calldata associatedData
    ) internal returns (CallObject[] memory) {
        if (msg.sender != tx.origin) {
            revert MustBeEOA();
        }

        if (calls.length != returnValues.length) {
            revert LengthMismatch();
        }

        _setPortalOpen(calls, returnValues);
        _populateCallsAndReturnValues(calls, returnValues);
        _populateAssociatedDataStore(associatedData);
        _populateCallIndices();

        return calls;
    }

    function _executeAndVerifyCalls(bytes memory callData) internal {
        CallObject[] memory calls = abi.decode(callData, (CallObject[]));
        uint256 l = calls.length;
        for (uint256 i = 0; i < l; i++) {
            _setCurrentlyExecutingCallIndex(i);
            _executeAndVerifyCall(i);
        }

        _setPortalClosed();
        _cleanUpStorage();
        emit VerifyStxn();
    }

    /// @dev Executes a single call and verifies the result by generating the call-return pair ID
    /// @param i The index of the CallObject and returnobject to be executed and verified
    function _executeAndVerifyCall(uint256 i) internal {
        (CallObject memory callObj, ReturnObject memory retObj) = getPair(i);
        if (callObj.amount > address(this).balance) {
            revert OutOfEther();
        }

        (bool success, bytes memory returnvalue) =
            callObj.addr.call{gas: callObj.gas, value: callObj.amount}(callObj.callvalue);
        if (!success) {
            revert CallFailed();
        }

        if (keccak256(retObj.returnvalue) != keccak256(returnvalue)) {
            revert CallVerificationFailed();
        }
    }

    /// @dev Resets the trace stores with the provided calls and return values.
    /// @param calls An array of CallObject to be stored in callStore.
    /// @param returnValues An array of ReturnObject to be stored in returnStore.
    function _populateCallsAndReturnValues(CallObject[] memory calls, ReturnObject[] memory returnValues) internal {
        for (uint256 i = 0; i < calls.length; i++) {
            callStore.push().store(calls[i]);
            returnStore.push(returnValues[i]);

            // Populating hintdices value while setting execution data
            bytes32 key = keccak256(abi.encode(calls[i]));
            hintdicesStoreKeyList.push(key);
            hintdicesStore[key].push(i);
        }
    }

    function _populateCallIndices() internal {
        uint256 l = callStore.length;
        for (uint256 i = 0; i < l; i++) {
            Call memory call = Call({callId: keccak256(abi.encode(_getCall(i))), index: i});
            callList.push(call);
            emit CallPopulated(_getCall(i), i);
        }
    }

    /// @notice Populates the associatedDataStore with a list of key-value pairs
    /// @param associatedData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function _populateAssociatedDataStore(AdditionalData[] memory associatedData) internal {
        uint256 l = associatedData.length;
        for (uint256 i = 0; i < l; i++) {
            associatedDataKeyList.push(associatedData[i].key);
            associatedDataStore[associatedData[i].key] = associatedData[i].value;
        }
    }

    function _expectCallAt(CallObject memory callObj, uint256 index) internal view {
        if (keccak256(abi.encode(_getCall(index))) != keccak256(abi.encode(callObj))) {
            revert CallPositionFailed(callObj, index);
        }
    }
}
