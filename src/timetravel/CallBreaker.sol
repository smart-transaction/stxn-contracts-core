// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./CallBreakerStorage.sol";

contract CallBreaker is CallBreakerStorage {
    ReturnObject[] public returnStore;
    mapping(bytes32 => int256) public callbalanceStore;
    mapping(bytes32 => bool) public callbalanceKeySet;
    bytes32[] public callbalanceKeyList;

    error OutOfReturnValues();
    error OutOfEther();
    error CallFailed();
    error TimeImbalance();

    event EnterPortal(string message, CallObject callObj, ReturnObject returnvalue, bytes32 pairid, int256 updatedcallbalance);
    event VerifyStxn();

    constructor() {
        _setPortalClosed();
    }

    receive() external payable onlyPortalOpen {
        // what about setting up the stack here? i think it's fine, because the stack is set up before the call is made.
        uint256 gasAtStart = gasleft();

        // inline so that now "fallback" caller is not self but original caller
        // encode myself and my calldata
        CallObject memory callObj = CallObject({
            amount: msg.value,
            addr: address(this),
            // TODO bug potentially??? see first line of this function.
            gas: gasAtStart,
            callvalue: ""
        });
        (bool success, bytes memory returned_from_fallback) = address(this).delegatecall(abi.encode(callObj));

        require(success, "inside portalopen fallback Call Failed");
        // returned from fallback should be the return value of the verify function, which is nothing.
        require(returned_from_fallback.length == 0, "TimeImbalance");
        // call into enterPortal
    }

    function getCallReturnID(CallObject memory callObj, ReturnObject memory returnObj) public pure returns (bytes32) {
        // Use keccak256 to generate a unique ID for a pair of CallObject and ReturnObject.
        return keccak256(abi.encode(callObj, returnObj));
    }

    /// this: takes in a call (structured as a CallObj), puts out a return value from the record of return values.
    /// also: does some accounting that we saw a given pair of call and return values once, and returns a thing off the emulated stack.
    /// called as reentrancy in order to balance the calls of the solution and make things validate.
    function enterPortal(bytes calldata input) external payable onlyPortalOpen returns (bytes memory) {
        require(returnStore.length > 0, "OutOfReturnValues");
        CallObject memory callobject = abi.decode(input, (CallObject));

        ReturnObject memory returnvalue = returnStore[returnStore.length - 1];
        bytes32 pairID = getCallReturnID(callobject, returnvalue);

        returnStore.pop();


        // todo this may be optimizable
        if (callbalanceStore[pairID] == 0 && callbalanceKeySet[pairID] == false) {
            callbalanceStore[pairID] = 1;
            callbalanceKeyList.push(pairID);
            callbalanceKeySet[pairID] = true;
        } else {
            callbalanceStore[pairID]++;
        }

        emit EnterPortal("enterPortal", callobject, returnvalue, pairID, callbalanceStore[pairID]);
        return returnvalue.returnvalue;
    }


    // this is what the searcher calls to finally execute and then validate everything
    function verify(bytes memory callsBytes, bytes memory returnsBytes) external payable {
        emit VerifyStxn();

        // TODO is this correct- calling convention costs some gas. it could be different before and after the stack setup.
        // this is for the isPortalOpen part below.
        // uint256 gasAtStart = gasleft();
        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory return_s = abi.decode(returnsBytes, (ReturnObject[]));

        //emit LogReturnStoreLength(return_s.length);

        require(calls.length == return_s.length, "LengthMismatch");

        if (isPortalOpen()) {
            revert("PortalOpen");
        }

        _setPortalOpen();

        delete returnStore;

        // if that EIP that comes through for temporary storage (within-transactional) ever gets approved, we can save some gas here :)
        for (uint256 i = 0; i < return_s.length; i++) {
            returnStore.push(return_s[i]);
        }

        // for all the calls, go check that the return value is actually the return value.
        for (uint256 i = 0; i < calls.length; i++) {
            require(address(this).balance >= calls[i].amount, "OutOfFunds");

            (bool success, bytes memory returnvalue) =
                calls[i].addr.call{gas: calls[i].gas, value: calls[i].amount}(calls[i].callvalue);

            require(success, "checking CallFailed");
            bytes32 pairID = getCallReturnID(calls[i], ReturnObject(returnvalue));

            // todo write tests for this two-sets-and-a-list situation, and think about optimization.
            if (callbalanceKeySet[pairID] == false) {
                callbalanceStore[pairID] = -1;
                callbalanceKeyList.push(pairID);
                callbalanceKeySet[pairID] = true;
            } else {
                callbalanceStore[pairID]--;
            }
        }

        for (uint256 i = 0; i < callbalanceKeyList.length; i++) {
            require(callbalanceStore[callbalanceKeyList[i]] == 0, "TimeImbalance: callbalanceStore not zeroed out");
        }

        // free the returnStore
        for (uint256 i = 0; i < returnStore.length; i++) {
            delete returnStore[i];
        }

        delete returnStore;
        delete callbalanceKeyList;
        // TODO is there any more storage to clear out?

        // later we need to make sure that we wipe ERC20 balances correctly as intended
        address payable blockBuilder = payable(block.coinbase);
        blockBuilder.transfer(address(this).balance);

        _setPortalClosed();
    }

    fallback(bytes calldata input) external payable returns (bytes memory) {
        return this.enterPortal(input);
    }
}
