// intended to be used as `contract x is CallBreakerUser`
// as in, it stores a callbreaker, and can make some assertions about callbreaker state!

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.2 <0.9.0;

import "../timetravel/CallBreaker.sol";

contract SmarterContract {
    CallBreaker public callbreaker;
    constructor(address _callbreaker) {
        callbreaker = CallBreaker(payable(_callbreaker));
    }

    function _ensureTurnerOpen() public view {
        require(callbreaker.isPortalOpen(), "CallBreakerUser: turner is not open");
    }

    modifier ensureTurnerOpen() {
        _ensureTurnerOpen();
        _;
    }

    // checks if the portal is open and we're currently in index 0 of the portal
    modifier noFrontRun() {
        frontrunBlocker();
        _;
    }

    function frontrunBlocker() internal view {
        require(callbreaker.getCurrentlyExecuting()==0, "CallBreakerUser: frontrunBlocker expected call index 0");
    }

    modifier noBackRun() {
        backrunBlocker();
        _;
    }

    function backrunBlocker() internal view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        uint256 reversecurrentlyExecuting = callbreaker.reverseIndex(currentlyExecuting);
        require (reversecurrentlyExecuting == 0, "CallBreakerUser: noBackRun expected reverse call index 0");
    }

    modifier noBackRunOrFrontRun() {
        soloExecuteBlocker();
        _;
    }

    // no backruns, no frontruns, no problem. you need to tip or you are unlikely to get executed!
    function soloExecuteBlocker() internal view {
        frontrunBlocker();
        backrunBlocker();
    }

    // this returns the call index, callobj, and returnobj of the currently executing call
    // time travel here- it returns the returnobj of the currently executing call
    function myCallData() internal view returns (CallObject memory, ReturnObject memory) {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        return callbreaker.getPair(currentlyExecuting);
    }

    // make sure there's a future call to this callobject after the current call
    // this iterates over all the call indices and makes sure there's one after the current call
    // you can add a hint and make it cheaper...
    function assertFutureCallTo(CallObject memory callObj) internal view {
        uint256[] memory cinds = callbreaker.getCallIndex(callObj);
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        for (uint256 i = 0; i < cinds.length; i++) {
            if (cinds[i] > currentlyExecuting) {
                return;
            }
        }
        revert("CallBreakerUser: assertFutureCallTo expected a future call to this callobject");
    }

    function assertFutureCallTo(CallObject memory callObj, uint256 hintdex) internal view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        bytes32 callObjHash = keccak256(abi.encode(callObj));
        bytes32 outputHash = keccak256(abi.encode(callbreaker.getCallListAt(hintdex)));
        require(hintdex > currentlyExecuting, "CallBreakerUser: assertFutureCallTo expected a future call to this callobject");
        require(outputHash == callObjHash, "CallBreakerUser: assertFutureCallTo expected a future call to this callobject");
    }

    /// @dev makes sure the next call is to this callobj
    function assertNextCallTo(CallObject memory callObj) internal view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        bytes32 callObjHash = keccak256(abi.encode(callObj));
        bytes32 outputHash = keccak256(abi.encode(callbreaker.getCallListAt(currentlyExecuting+1)));
        require(outputHash == callObjHash, "CallBreakerUser: assertNextCallTo expected the next call to be to this callobject");
    }
}