// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./CallBreakerStorage.sol";

contract CallBreaker is CallBreakerStorage {
    error OutOfReturnValues();
    error OutOfEther();
    error CallFailed();
    error TimeImbalance();
    event CallObjectLog(string message, CallObject callObj);
    event ReturnObjectLog(string message, bytes returnvalue);
    event CallBalance(string message, bytes32 pairID, int256 callbalance);

    ReturnObject[] public returnStore;
    mapping(bytes32 => int256) public callbalanceStore;
    mapping(bytes32 => bool) public callbalanceKeySet;
    bytes32[] public callbalanceKeyList;

    constructor() {
        _setPortalClosed();
    }

    receive() external onlyPortalOpen payable {
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

        require(success, "inside portalopen fallback CallFailed");
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

        ReturnObject memory returnvalue = returnStore[returnStore.length - 1];
        emit ReturnObjectLog("enterportal", returnvalue.returnvalue);
        returnStore.pop();
        
        CallObject memory callobject = abi.decode(input, (CallObject));
        emit CallObjectLog("enterPortal", callobject);

        bytes32 pairID = getCallReturnID(callobject, returnvalue);

        // todo this may be optimizable
        if (callbalanceStore[pairID] == 0 && callbalanceKeySet[pairID] == false) {
            callbalanceStore[pairID] = 1;
            callbalanceKeyList.push(pairID);
            callbalanceKeySet[pairID] = true;
        } else {
            callbalanceStore[pairID]++;
        }

        emit CallBalance("enterPortal", pairID, callbalanceStore[pairID]);
        return returnvalue.returnvalue;
    }

    fallback(bytes calldata input) external payable returns (bytes memory) {
        return this.enterPortal(input);
    }

    // this is what the searcher calls to finally execute and then validate everything
    function verify(bytes memory callsBytes, bytes memory returnsBytes) external payable {
        // TODO is this correct- calling convention costs some gas. it could be different before and after the stack setup.
        // this is for the isPortalOpen part below.
        // uint256 gasAtStart = gasleft();
        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory return_s = abi.decode(returnsBytes, (ReturnObject[]));

        require(calls.length == return_s.length, "LengthMismatch");

        // i think: if the portal is open, then we are in a recursive call, so we should just call the fallback function and let that *record* execution of this function...
        // but then we should also do the rest of the function, which is to check that the return values are correct.
        // TODO this is a probable source of bugs. solidity engineer please check this very very carefully.
        // leaving it as a revert for now.
        if (isPortalOpen()) {
            // // # inline so that now "fallback" caller is not self but original caller
            // // encode myself and my calldata
            // bytes memory callValue = abi.encodeWithSignature("verify(bytes, bytes)", callsBytes, returnsBytes);
            // CallObject memory callObj = CallObject({
            //     amount: msg.value,
            //     addr: address(this),
            //     // TODO bug potentially??? see first line of this function.
            //     gas: gasAtStart,
            //     callvalue: callValue
            // });
            // (bool success, bytes memory returned_from_fallback) = address(this).delegatecall(abi.encode(callObj));

            // require(success, "inside portalopen fallback CallFailed");
            // // returned from fallback should be the return value of the verify function, which is nothing.
            // require(returned_from_fallback.length == 0, "TimeImbalance");
            revert("PortalOpen");
        }

        _setPortalOpen();

        // todo: see the return statement above. eventually you'll want to have a stack of stacks maybe, with accounting getting resolved on each layer
        // todo: an alternative is to have a bunch of parallel timeturners.
        // for now, just make sure the returnstore is wiped before you start working.
        delete returnStore;

        // if that EIP that comes through for temporary storage (within-transactional) ever gets approved, we can save some gas here :)
        for (uint256 i = 0; i < return_s.length; i++) {
            returnStore.push(return_s[i]);
        }

        // for all the calls, go check that the return value is actually the return value.
        for (uint256 i = 0; i < calls.length; i++) {
            require(address(this).balance >= calls[i].amount, "OutOfFunds");

            emit CallObjectLog("verify pre-call", calls[i]);

            (bool success, bytes memory returnvalue) =
                calls[i].addr.call{gas: calls[i].gas, value: calls[i].amount}(calls[i].callvalue);

            require(success, "checking CallFailed");

            emit ReturnObjectLog("verify post-call", returnvalue);

            bytes32 pairID = getCallReturnID(calls[i], ReturnObject(returnvalue));

            // todo write tests for this two-sets-and-a-list situation, and think about optimization.
            if (callbalanceKeySet[pairID] == false) {
                callbalanceStore[pairID] = -1;
                callbalanceKeyList.push(pairID);
                callbalanceKeySet[pairID] = true;
            } else {
                callbalanceStore[pairID]--;
            }
            emit CallBalance("verifyCall", pairID, callbalanceStore[pairID]);
        }

        for (uint256 i = 0; i < callbalanceKeyList.length; i++) {
            emit CallBalance("verifyCheck", callbalanceKeyList[i], callbalanceStore[callbalanceKeyList[i]]);
            require(callbalanceStore[callbalanceKeyList[i]] == 0, "TimeImbalance");
        }

        // free the returnStore
        for (uint256 i = 0; i < returnStore.length; i++) {
            delete returnStore[i];
        }

        delete returnStore;
        delete callbalanceKeyList;
        // TODO is there any more storage to clear out?

        // later we need to make sure that we wipe balances correctly as intended
        address payable blockBuilder = payable(block.coinbase);
        blockBuilder.transfer(address(this).balance);

        _setPortalClosed();
    }
}
