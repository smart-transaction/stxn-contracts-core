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

    error OutOfReturnValues();
    error OutOfEther();
    error CallFailed();
    error TimeImbalance();
    error EmptyCalldata();
    error LengthMismatch();
    error CallVerificationFailed();

    event EnterPortal(string message, CallObject callObj, ReturnObject returnvalue, bytes32 pairid, int256 updatedcallbalance);
    event VerifyStxn();

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

        // Pop the last ReturnObject after getting its ID
        ReturnObject memory returnvalue = returnStore[returnStore.length - 1];
        returnStore.pop();
        
        // Decode the input and fetch the last ReturnObject from returnStore in one step
        bytes32 pairID = getCallReturnID(
            abi.decode(input, (CallObject)),
            returnvalue
        );

        CallObject memory callobject = abi.decode(input, (CallObject));

        if (callbalanceStore[pairID].set == false) {
            callbalanceStore[pairID].balance = 1;
            callbalanceKeyList.push(pairID);
            callbalanceStore[pairID].set = true;
        } else {
            callbalanceStore[pairID].balance++;
        }

        emit EnterPortal("enterPortal", callobject, returnvalue, pairID, callbalanceStore[pairID].balance);
        return returnvalue.returnvalue;
    }


    // this is what the searcher calls to finally execute and then validate everything
    function verify(bytes memory callsBytes, bytes memory returnsBytes) external payable onlyPortalClosed() {
        // TODO is this correct- calling convention costs some gas. it could be different before and after the stack setup.
        // this is for the isPortalOpen part below.
        // uint256 gasAtStart = gasleft();
        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory return_s = abi.decode(returnsBytes, (ReturnObject[]));
        if (calls.length != return_s.length) {
            revert LengthMismatch();
        }

        delete returnStore;

        // if that EIP that comes through for temporary storage (within-transactional) ever gets approved, we can save some gas here :)
        for (uint256 i = 0; i < return_s.length; i++) {
            returnStore.push(return_s[i]);
        }

        // for all the calls, go check that the return value is actually the return value.
        for (uint256 i = 0; i < calls.length; i++) {
            if (address(this).balance < calls[i].amount ) {
                revert OutOfEther();
            }

            (bool success, bytes memory returnvalue) =
                calls[i].addr.call{gas: calls[i].gas, value: calls[i].amount}(calls[i].callvalue);

            if (!success) {
                revert CallFailed();
            }
            bytes32 pairID = getCallReturnID(calls[i], ReturnObject(returnvalue));

            // todo write tests for this two-sets-and-a-list situation, and think about optimization.
            if (callbalanceStore[pairID].set == false) {
                callbalanceStore[pairID].balance = -1;
                callbalanceKeyList.push(pairID);
                callbalanceStore[pairID].set = true;
            } else {
                callbalanceStore[pairID].balance--;
            }
        }

        for (uint256 i = 0; i < callbalanceKeyList.length; i++) {
            if (callbalanceStore[callbalanceKeyList[i]].balance != 0) {
                revert TimeImbalance();
            }
        }

        delete returnStore;
        delete callbalanceKeyList;
        // TODO is there any more storage to clear out?

        // later we need to make sure that we wipe ERC20 balances correctly as intended
        address payable blockBuilder = payable(block.coinbase);
        emit VerifyStxn();
        blockBuilder.transfer(address(this).balance);
    }
}
