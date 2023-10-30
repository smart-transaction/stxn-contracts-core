// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
// they're gonna push a callobject stack
// the call will have three things inside.
// one is gonna call crontwocounter
// the second thing is gonna make sure we're in the timeturner, clean up the timeturner, tip the pusher
// tipping the pusher need to happen directly in the laminated mempool
// the third thing is gonna schedule itself. how are we gonna schedule ourselves?

// OK HERE IS THE SOLUTION
// laminated_mempool[n] = push(vec(call counter, cleanupcalls (calls enterportal), tip, copy(laminated_mempool[n], laminated_mempool[sequence_num])))
// call counter just happens from the laminated proxy, easy
// calling enterportal is easy too
// tipping is easy. just... transfer... but to who? needs to get set in the verify call?
// copying those bytes. has to happen from the laminated proxy

import "../../src/timetravel/CallBreaker.sol";
import "../../src/lamination/LaminatedProxy.sol";

contract CronTwoLogic {
    CallBreaker public callbreaker;
    LaminatedProxy public laminatedProxy;

    bool _shouldTerminate = false;
    uint256 _tipWei;
    uint32 _recurringDelay;

    constructor(address callbreakerLocation, address laminatedProxyLocation, uint256 tipAmount, uint32 recurringDelay) {
        callbreaker = CallBreaker(payable(callbreakerLocation));
        laminatedProxy = LaminatedProxy(payable(laminatedProxyLocation));
        _tipWei = tipAmount;
        _recurringDelay = recurringDelay;
    }

    // todo: add a better shouldTerminate condition (some code?)
    // todo: add a better automatic function for tips?
    // todo: add a better delay: should not just be a constant! this adds jitter if there's an execution delay.
    function cronTrailer() public {
        // start by... tipping the solver
        bytes32 tipAddrKey = keccak256(abi.encodePacked("tipYourBartender"));
        bytes memory tipAddrBytes = callbreaker.fetchFromAssociatedDataStore(tipAddrKey);
        address tipAddr = abi.decode(tipAddrBytes, (address));
        payable(tipAddr).transfer(_tipWei);
        uint256 currentSequenceNum = laminatedProxy.getExecutingSequenceNumber();

        // next, push this job back into the laminatedproxy :) to reschedule it
        if (!_shouldTerminate) {
            (bool _init, CallObjectWithDelegateCall[] memory calls) =
                laminatedProxy.viewDeferredCall(currentSequenceNum);
            require(_init, "CallObjectHolder not initialized");
            bytes memory callsbytes = abi.encode(calls);
            laminatedProxy.push(callsbytes, _recurringDelay);
        }
        // call enterportal on the pull call- this ensures you were called in the CB
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(laminatedProxy),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", currentSequenceNum)
        });
        CallObjectWithIndex memory callObjWithIndex = CallObjectWithIndex({callObj: callObj, index: 0});
        callbreaker.enterPortal(abi.encode(callObjWithIndex));
    }
}
