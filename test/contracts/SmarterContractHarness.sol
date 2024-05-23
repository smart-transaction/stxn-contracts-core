// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import {SmarterContract, CallObject} from "src/timetravel/SmarterContract.sol";

contract SmarterContractHarness is SmarterContract {
    constructor(address callbreakerAddress) SmarterContract(callbreakerAddress) {}

    function dummyFutureCall() public pure returns (bool) {
        return true;
    }

    function assertFutureCallTestHarness() public view {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        assertFutureCallTo(callObjs[0]);
    }

    function assertFutureCallWithIndexTestHarness() public view {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        assertFutureCallTo(callObjs[0], 1);
    }

    function assertNextCallTestHarness() public view {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("dummyFutureCall()")
        });

        assertNextCallTo(callObjs[0]);
    }
}
