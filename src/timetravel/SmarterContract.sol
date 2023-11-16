// intended to be used as `contract x is CallBreakerUser`
// as in, it stores a callbreaker, and can make some assertions about callbreaker state!

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.2 <0.9.0;

import "../timetravel/CallBreaker.sol";

contract SmarterContract {
    CallBreaker public callbreaker;

    /// @dev Selector 0xab63c583
    error FutureCallExpected();

    /// @dev Selector 0xa7ee1685
    error CallMismatch();

    /// @notice Error thrown when calling a function that can only be called when the portal is open
    /// @dev Selector 0x59f0d709
    error PortalClosed();

    /// @dev Selector 0x3df7e356
    error IllegalFrontrun();

    /// @dev Selector 0xd1cb360d
    error IllegalBackrun();

    constructor(address _callbreaker) {
        callbreaker = CallBreaker(payable(_callbreaker));
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

    function frontrunBlocker() public view {
        if (callbreaker.getCurrentlyExecuting() != 0) {
            revert IllegalFrontrun();
        }
    }

    modifier noBackRun() {
        backrunBlocker();
        _;
    }

    function backrunBlocker() public view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        uint256 reversecurrentlyExecuting = callbreaker.getReverseIndex(currentlyExecuting);
        require(reversecurrentlyExecuting == 0, "CallBreakerUser: noBackRun expected reverse call index 0");
        if (reversecurrentlyExecuting != 0) {
            revert IllegalBackrun();
        }
    }

    modifier noBackRunOrFrontRun() {
        soloExecuteBlocker();
        _;
    }

    function _ensureTurnerOpen() internal view {
        if (!callbreaker.isPortalOpen()) {
            revert PortalClosed();
        }
    }

    // no backruns, no frontruns, no problem. you need to tip or you are unlikely to get executed!
    function soloExecuteBlocker() public view {
        frontrunBlocker();
        backrunBlocker();
    }

    // this returns the call index, callobj, and returnobj of the currently executing call
    // time travel here- it returns the returnobj of the currently executing call
    function myCallData() public view returns (CallObject memory, ReturnObject memory) {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        return callbreaker.getPair(currentlyExecuting);
    }

    // make sure there's a future call to this callobject after the current call
    // this iterates over all the call indices and makes sure there's one after the current call
    // you can add a hint and make it cheaper...
    function assertFutureCallTo(CallObject memory callObj) public view {
        uint256[] memory cinds = callbreaker.getCallIndex(callObj);
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        for (uint256 i = 0; i < cinds.length; i++) {
            if (cinds[i] > currentlyExecuting) {
                return;
            }
        }
        revert FutureCallExpected();
    }

    function assertFutureCallTo(CallObject memory callObj, uint256 hintdex) public view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        bytes32 callObjHash = keccak256(abi.encode(callObj));
        bytes32 outputHash = callbreaker.getCallListAt(hintdex).callId;
        if (hintdex <= currentlyExecuting) {
            revert FutureCallExpected();
        }
        if (outputHash != callObjHash) {
            revert CallMismatch();
        }
    }

    /// @dev makes sure the next call is to this callobj
    function assertNextCallTo(CallObject memory callObj) public view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        bytes32 callObjHash = keccak256(abi.encode(callObj));
        bytes32 outputHash = callbreaker.getCallListAt(currentlyExecuting + 1).callId;
        if (outputHash != callObjHash) {
            revert CallMismatch();
        }
    }
}
