// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./CallBreakerStorage.sol";

struct CallBalance {
    bool set;
    int256 balance;
}

contract CallBreaker is CallBreakerStorage {
    ReturnObject[] public returnStore;
    mapping(bytes32 => CallBalance) public callbalanceStore;
    bytes32[] public callbalanceKeyList;

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

    event EnterPortal(CallObject callObj, ReturnObject returnvalue, bytes32 pairid, int256 updatedcallbalance);
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
        ReturnObject memory lastReturn = popLastReturn();

        // Decode the input to obtain the CallObject and calculate a unique ID representing the call-return pair
        CallObject memory callObj = abi.decode(input, (CallObject));
        bytes32 pairID = getCallReturnID(callObj, lastReturn);

        // Update or initialize the balance of the call-return pair
        incrementCallBalance(pairID);

        emit EnterPortal(callObj, lastReturn, pairID, callbalanceStore[pairID].balance);
        return lastReturn.returnvalue;
    }

    /// @notice Verifies that the given calls, when executed, gives the correct return values
    function verify(bytes memory callsBytes, bytes memory returnsBytes) external payable onlyPortalClosed {
        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory return_s = abi.decode(returnsBytes, (ReturnObject[]));

        if (calls.length != return_s.length) {
            revert LengthMismatch();
        }

        resetReturnStoreWith(return_s);

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
            returnStore.push(return_s[i]);
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
    }

    // Helper function to fetch and remove the last ReturnObject from the storage
    function popLastReturn() internal returns (ReturnObject memory) {
        ReturnObject memory lastReturn = returnStore[returnStore.length - 1];
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
