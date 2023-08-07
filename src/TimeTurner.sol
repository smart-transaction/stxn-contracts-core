// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

struct CallObject {
    uint256 amount;
    address addr;
    uint256 gas;
    /// should be abi encoded
    bytes callvalue;
}

struct ReturnObject {
    /// should be abi encoded
    bytes returnvalue;
}

contract TimeTurner {
    error PortalClosed();
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
    bool public isPortalOpen;

    constructor() {
        isPortalOpen = false;
    }

    // QUESTION i think the actual correct behavior may be to redirect somehow to enterPortal, but i'm not sure.
    // TODO test me
    receive() external payable {
        // revert
        revert();
    }

    function getCallReturnID(CallObject memory callObj, ReturnObject memory returnObj) public pure returns (bytes32) {
        // Use keccak256 to generate a unique ID for a pair of CallObject and ReturnObject.
        return keccak256(abi.encode(callObj, returnObj));
    }

    /// this: takes in a call (structured as a CallObj), puts out a return value from the record of return values.
    /// also: does some accounting that we saw a given pair of call and return values once, and returns a thing off the emulated stack.
    /// called as reentrancy in order to balance the calls of the solution and make things validate.
    // todo understand better when this is called and how it's used.
    function enterPortal(bytes calldata input) external payable returns (bytes memory) {
        require(isPortalOpen, "PortalClosed");
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
    function verify(CallObject[] memory calls, ReturnObject[] memory return_s) external payable {
        require(calls.length == return_s.length, "LengthMismatch");
        
        // i think: if the portal is open, then we are in a recursive call, so we should just call the fallback function and let that *record* execution...
        // but then we should also do the rest of the function, which is to check that the return values are correct.
        if (isPortalOpen) {
            // # inline so that now "fallback" caller is not self but original caller
            (bool success, bytes memory returned_from_fallback) = address(this).delegatecall(abi.encode(calls));
            require(success, "inside portalopen fallback CallFailed");
            // returned from fallback should be the return value of the verify function, which is nothing.
            // todo check that this is correct with vlad.
            require(returned_from_fallback.length == 0, "TimeImbalance");
        }

        isPortalOpen = true;

        // todo: see the if statement above. what if the portal is open and we copy over return_s again? this does not seem correct. think more about this.
        delete returnStore;

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


        // NOTE are we checking that the OTHER callbalancestores are zero? i think we should be.
        // NOTE this is vlad's original code
        // for (uint256 i = 0; i < calls.length; i++) {
        //     bytes32 pairID = getCallReturnID(calls[i], ReturnObject(return_s[i].returnvalue));

        //     require(callbalanceStore[pairID] == 0, "TimeInbalance");
        // }
        // todo ask vlad if i'm fixing a bug or making one here :)
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
        // TODO clear some other storage out

        isPortalOpen = false;
    }
}

// what you should write after that:
// write a quine: this is a contract that deploys itself...
// just use a contract that create2s itself?
// maybe 2 contracts that create2 each other...

// after that: mempool laminate?
// main uncertainty is "idk what's possible"

// learn K's tools (like the solvers) to help define the scope of the work
// briefly review KEVM usage

// discuss gastoken situation

// "flashpill" -> ERC20 where anyone can move any balances for anyone (including negative), as long as they end up back at zero :)
// claudia should figure out how to do this!
// code it like flash loans- you can do anything you want as long as you end up back at zero.

// DM daniel about contract harassment, ask if he wants ops help again, figure out github organization
