// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";

import {
    CallBreaker, CallObject, ReturnObject, CallObjectWithIndex, AdditionalData
} from "src/timetravel/CallBreaker.sol";
import {CallBreakerHarness} from "test/contracts/CallBreakerHarness.sol";

contract CallBreakerTest is Test {
    CallBreakerHarness public callbreaker;

    function setUp() public {
        callbreaker = new CallBreakerHarness();
    }

    function testExpectCallAt() external {
        CallObject[] memory calls = new CallObject[](1);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](1);
        returnValues[0] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        callbreaker.expectCallAtHarness(calls[0], 0);

        CallObject[] memory falseCalls = new CallObject[](1);
        falseCalls[0] = CallObject({amount: 0, addr: address(0xbabe), gas: 1000000, callvalue: ""});

        vm.expectRevert(abi.encodeWithSelector(CallBreaker.CallPositionFailed.selector, falseCalls[0], 0));
        callbreaker.expectCallAtHarness(falseCalls[0], 0);
    }

    function testPopulateCallIndices() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        callbreaker.expectCallAtHarness(calls[0], 0);
        callbreaker.expectCallAtHarness(calls[1], 1);

        CallObject[] memory falseCalls = new CallObject[](1);
        falseCalls[0] = CallObject({amount: 0, addr: address(0xbabe), gas: 1000000, callvalue: ""});

        vm.expectRevert(abi.encodeWithSelector(CallBreaker.CallPositionFailed.selector, falseCalls[0], 0));
        callbreaker.expectCallAtHarness(falseCalls[0], 0);
    }

    function testExecuteAndVerifyCall() external {
        CallObject[] memory calls = new CallObject[](1);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](1);
        returnValues[0] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        callbreaker._executeAndVerifyCallHarness(0);

        // Should fail on incorrect return values
        ReturnObject[] memory falseRet = new ReturnObject[](1);
        falseRet[0] = ReturnObject({returnvalue: abi.encode(uint256(0))});

        callbreaker.resetTraceStoresWithHarness(calls, falseRet);
        callbreaker.populateCallIndicesHarness();

        vm.expectRevert(CallBreaker.CallVerificationFailed.selector);
        callbreaker._executeAndVerifyCallHarness(0);

        // false CallObject with a high amount to test OutOfEther condition
        CallObject[] memory falseCalls = new CallObject[](1);
        falseCalls[0] = CallObject({amount: 1000000000, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        callbreaker.resetTraceStoresWithHarness(falseCalls, returnValues);
        callbreaker.populateCallIndicesHarness();
        vm.expectRevert(CallBreaker.OutOfEther.selector);
        callbreaker._executeAndVerifyCallHarness(0);
    }

    function testCleanUpStorage() external {
        assertEq(callbreaker.getCallStoreLengthHarness(), 0);
        assertEq(callbreaker.getReturnStoreLengthHarness(), 0);
        assertEq(callbreaker.getCallListLengthHarness(), 0);
        assertEq(callbreaker.getAssociatedDataKeyListLengthHarness(), 0);
        assertEq(callbreaker.getHintdicesStoreKeyListLengthHarness(), 0);

        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        assertEq(callbreaker.getCallStoreLengthHarness(), 2);
        assertEq(callbreaker.getReturnStoreLengthHarness(), 2);
        assertEq(callbreaker.getCallListLengthHarness(), 2);
        assertEq(callbreaker.getAssociatedDataKeyListLengthHarness(), 0);
        assertEq(callbreaker.getHintdicesStoreKeyListLengthHarness(), 0);

        callbreaker._executeAndVerifyCallHarness(0);
        callbreaker._executeAndVerifyCallHarness(1);

        callbreaker.cleanUpStorageHarness();

        assertEq(callbreaker.getCallStoreLengthHarness(), 0);
        assertEq(callbreaker.getReturnStoreLengthHarness(), 0);
        assertEq(callbreaker.getCallListLengthHarness(), 0);
        assertEq(callbreaker.getAssociatedDataKeyListLengthHarness(), 0);
        assertEq(callbreaker.getHintdicesStoreKeyListLengthHarness(), 0);
    }

    function testPopulateAssociatedDataStore() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        callbreaker._executeAndVerifyCallHarness(0);
        callbreaker._executeAndVerifyCallHarness(1);

        AdditionalData[] memory associatedData = new AdditionalData[](2);
        associatedData[0] = AdditionalData({
            key: keccak256(abi.encodePacked("tipYourBartender")),
            value: abi.encodePacked(address(0xdeadbeef))
        });
        associatedData[1] = AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(0)});

        callbreaker.populateAssociatedDataStoreHarness(associatedData);
    }

    function testPopulateHintdices() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        callbreaker._executeAndVerifyCallHarness(0);
        callbreaker._executeAndVerifyCallHarness(1);

        AdditionalData[] memory associatedData = new AdditionalData[](2);
        associatedData[0] = AdditionalData({
            key: keccak256(abi.encodePacked("tipYourBartender")),
            value: abi.encodePacked(address(0xdeadbeef))
        });
        associatedData[1] = AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(0)});

        callbreaker.populateAssociatedDataStoreHarness(associatedData);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(calls[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(calls[1])), value: abi.encode(1)});
        bytes memory hintindices = abi.encode(hintdices);

        callbreaker.populateHintdicesHarness(hintindices);
    }

    function testInsertIntoHintdices() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        callbreaker._executeAndVerifyCallHarness(0);
        callbreaker._executeAndVerifyCallHarness(1);

        AdditionalData[] memory associatedData = new AdditionalData[](2);
        associatedData[0] = AdditionalData({
            key: keccak256(abi.encodePacked("tipYourBartender")),
            value: abi.encodePacked(address(0xdeadbeef))
        });
        associatedData[1] = AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(0)});

        callbreaker.populateAssociatedDataStoreHarness(associatedData);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(calls[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(calls[1])), value: abi.encode(1)});
        bytes memory hintindices = abi.encode(hintdices);

        callbreaker.populateHintdicesHarness(hintindices);
        callbreaker.insertIntoHintdicesHarness(keccak256(abi.encode(calls[0])), 2);
    }

    function testInsertIntoAssociatedDataStore() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});

        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});

        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        callbreaker._executeAndVerifyCallHarness(0);
        callbreaker._executeAndVerifyCallHarness(1);

        AdditionalData[] memory associatedData = new AdditionalData[](2);
        associatedData[0] = AdditionalData({
            key: keccak256(abi.encodePacked("tipYourBartender")),
            value: abi.encodePacked(address(0xdeadbeef))
        });
        associatedData[1] = AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(0)});

        callbreaker.populateAssociatedDataStoreHarness(associatedData);

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(calls[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(calls[1])), value: abi.encode(1)});
        bytes memory hintindices = abi.encode(hintdices);

        callbreaker.populateHintdicesHarness(hintindices);

        callbreaker.insertIntoHintdicesHarness(keccak256(abi.encode(calls[0])), 2);

        callbreaker.insertIntoAssociatedDataStore(keccak256(abi.encodePacked("x")), abi.encode(uint256(0)));
    }

    function testGetCallIndex() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});
        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();

        AdditionalData[] memory hintdices = new AdditionalData[](2);

        hintdices[0] = AdditionalData({key: keccak256(abi.encode(calls[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(calls[1])), value: abi.encode(1)});

        callbreaker.populateHintdicesHarness(abi.encode(hintdices));

        uint256[] memory indices = callbreaker.getCallIndex(calls[0]);

        assertEq(indices.length, calls.length);
        assertEq(indices[calls.length - indices.length], calls.length - indices.length);
        assertEq(indices[calls.length - indices.length + 1], calls.length - indices.length + 1);
    }

    function testGetReturnValue() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: "foo"});
        returnValues[1] = ReturnObject({returnvalue: "bar"});
        callbreaker.resetTraceStoresWithHarness(calls, returnValues);

        CallObjectWithIndex memory input0 = CallObjectWithIndex({index: 0, callObj: calls[0]});
        bytes memory output0 = callbreaker.getReturnValue(input0);

        CallObjectWithIndex memory input1 = CallObjectWithIndex({index: 1, callObj: calls[1]});
        bytes memory output1 = callbreaker.getReturnValue(input1);

        assertEq(keccak256(returnValues[0].returnvalue), keccak256(output0));
        assertEq(keccak256(returnValues[1].returnvalue), keccak256(output1));
    }

    function testGetReverseIndex() external {
        CallObject[] memory calls = new CallObject[](2);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        calls[1] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        ReturnObject[] memory returnValues = new ReturnObject[](2);
        returnValues[0] = ReturnObject({returnvalue: ""});
        returnValues[1] = ReturnObject({returnvalue: ""});
        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();
        callbreaker.getReverseIndex(1);

        // Expect revert due to IndexMismatch
        vm.expectRevert(abi.encodeWithSelector(CallBreaker.IndexMismatch.selector, 2, 2));
        callbreaker.getReverseIndex(2);
    }

    function testGetCompleteCallIndexList() external {
        CallObject[] memory calls = new CallObject[](1);
        calls[0] = CallObject({amount: 0, addr: address(0xdeadbeef), gas: 1000000, callvalue: ""});
        ReturnObject[] memory returnValues = new ReturnObject[](1);
        returnValues[0] = ReturnObject({returnvalue: ""});
        callbreaker.resetTraceStoresWithHarness(calls, returnValues);
        callbreaker.populateCallIndicesHarness();
        callbreaker.getCompleteCallIndexList(calls[0]);
    }
}
