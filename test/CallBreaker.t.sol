// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";

import {CallBreaker, CallObject, ReturnObject} from "src/timetravel/CallBreaker.sol";
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

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encodePacked(address(0xdeadbeef));
        values[1] = abi.encode(uint256(0));
        bytes memory encodedData = abi.encode(keys, values);

        callbreaker.populateAssociatedDataStoreHarness(encodedData);
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

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encodePacked(address(0xdeadbeef));
        values[1] = abi.encode(uint256(0));
        bytes memory encodedData = abi.encode(keys, values);

        callbreaker.populateAssociatedDataStoreHarness(encodedData);

        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(calls[0]));
        hintdicesKeys[1] = keccak256(abi.encode(calls[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintindices = abi.encode(hintdicesKeys, hintindicesVals);

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

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encodePacked(address(0xdeadbeef));
        values[1] = abi.encode(uint256(0));
        bytes memory encodedData = abi.encode(keys, values);

        callbreaker.populateAssociatedDataStoreHarness(encodedData);

        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(calls[0]));
        hintdicesKeys[1] = keccak256(abi.encode(calls[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintindices = abi.encode(hintdicesKeys, hintindicesVals);

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

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encodePacked(address(0xdeadbeef));
        values[1] = abi.encode(uint256(0));
        bytes memory encodedData = abi.encode(keys, values);

        callbreaker.populateAssociatedDataStoreHarness(encodedData);

        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(calls[0]));
        hintdicesKeys[1] = keccak256(abi.encode(calls[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintindices = abi.encode(hintdicesKeys, hintindicesVals);

        callbreaker.populateHintdicesHarness(hintindices);

        callbreaker.insertIntoHintdicesHarness(keccak256(abi.encode(calls[0])), 2);

        callbreaker.insertIntoAssociatedDataStore(keccak256(abi.encodePacked("x")), abi.encode(uint256(0)));
    }
}
