// intended to be used as `contract x is CallBreakerUser`
// as in, it stores a callbreaker, and can make some assertions about callbreaker state!

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.2 <0.9.0;

import "../timetravel/CallBreaker.sol";

contract SmarterContract {
    CallBreaker public callbreaker;

    /// @notice The address passed was a zero address
    error AddressZero();

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

    /// @dev Selector 0xed32fe28
    error Unaudited();

    /// @dev Selector 0xc19f17a9
    error NotApproved();

    /// @notice Modifier to ensure that the Portal is open
    modifier onlyPortalOpen() {
        if (!callbreaker.isPortalOpen()) {
            revert PortalClosed();
        }
        _;
    }

    /// @notice Modifier to prevent frontrunning
    /// @dev Checks if the portal is open and we're currently in index 0 of the portal
    modifier noFrontRun() {
        frontrunBlocker();
        _;
    }

    /// @notice Modifier to prevent backrunning
    modifier noBackRun() {
        backrunBlocker();
        _;
    }

    /// @dev Constructs a new SmarterContract instance
    /// @param _callbreaker The address of the CallBreaker contract
    constructor(address _callbreaker) {
        if (_callbreaker == address(0)) {
            revert AddressZero();
        }

        callbreaker = CallBreaker(payable(_callbreaker));
    }

    /// @notice Returns the call index, callobj, and returnobj of the currently executing call
    /// @dev This function allows for time travel by returning the returnobj of the currently executing call
    /// @return A pair consisting of the CallObject and ReturnObject of the currently executing call
    function getCurrentExecutingPair() public view returns (CallObject memory, ReturnObject memory) {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        return callbreaker.getPair(currentlyExecuting);
    }

    /// @notice Prevents frontrunning by ensuring the currently executing call is the first in the list
    /// @custom:reverts IllegalFrontrun() when the currently executing call has a frontrunning call
    function frontrunBlocker() public view {
        if (callbreaker.getCurrentlyExecuting() != 0) {
            revert IllegalFrontrun();
        }
    }

    /// @notice Prevents backrunning by ensuring the currently executing call is the first in the reverse list
    /// @custom:reverts IllegalBackrun() when the currently executing call has a backrunning call
    function backrunBlocker() public view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        uint256 reversecurrentlyExecuting = callbreaker.getReverseIndex(currentlyExecuting);
        if (reversecurrentlyExecuting != 0) {
            revert IllegalBackrun();
        }
    }

    /// @notice Prevents both frontrunning and backrunning
    /// @dev This function calls both frontrunBlocker() and backrunBlocker() to ensure no frontrunning or backrunning can occur
    /// @dev It is recommended to tip to increase the likelihood of execution
    function soloExecuteBlocker() public view {
        frontrunBlocker();
        backrunBlocker();
    }

    /// @notice Ensures that there is a future call to the specified callobject after the current call
    /// @dev This iterates over all call indices and ensures there's one after the current call.
    ///      Adding a hintdex makes this cheaper.
    /// @param callObj The callobject to check for. This callObject should strictly be a future call
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

    /// @notice Ensures that there is a future call to the specified callobject after the current call
    /// @param callObj The callobject to check for. This callObject should strictly be a future call
    /// @param hintdex The hint index to start checking for future calls
    /// @custom:reverts FutureCallExpected() Hintdexes should always be in the future of the current executing call
    /// @custom:reverts CallMismatch() The callobject at the hintdex should match the specified callObject
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
    /// @notice Ensures that the next call is to the specified callobject
    /// @param callObj The callobject to check for the next call
    /// @custom:reverts CallMismatch() The callobject at the next index should match the specified callObject
    function assertNextCallTo(CallObject memory callObj) public view {
        uint256 currentlyExecuting = callbreaker.getCurrentlyExecuting();
        bytes32 callObjHash = keccak256(abi.encode(callObj));
        bytes32 outputHash = callbreaker.getCallListAt(currentlyExecuting + 1).callId;
        if (outputHash != callObjHash) {
            revert CallMismatch();
        }
    }
}
