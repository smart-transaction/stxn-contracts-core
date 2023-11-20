// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
//import {VmSafe} from "forge-std/Vm.sol";

import "../src/timetravel/CallBreaker.sol";

contract CallBreakerHarness is CallBreaker {
    function populateCallIndicesHarness() public {
        _populateCallIndices();
    }

    function resetTraceStoresWithHarness(CallObject[] memory calls, ReturnObject[] memory returnValues) public {
        _resetTraceStoresWith(calls, returnValues);
    }

    function _executeAndVerifyCallHarness(uint256 index) public {
        _executeAndVerifyCall(index);
    }

    function cleanUpStorageHarness() public {
        _cleanUpStorage();
    }

    function populateAssociatedDataStoreHarness(bytes memory encodedData) public {
        _populateAssociatedDataStore(encodedData);
    }

    function populateHintdicesHarness(bytes memory encodedData) public {
        _populateHintdices(encodedData);
    }

    function insertIntoHintdicesHarness(bytes32 key, uint256 value) public {
        _insertIntoHintdices(key, value);
    }

    function insertIntoAssociatedDataStore(bytes32 key, bytes memory value) public {
        _insertIntoAssociatedDataStore(key, value);
    }

    function expectCallAtHarness(CallObject memory callObj, uint256 index) public view {
        _expectCallAt(callObj, index);
    }
}

contract CallBreakerTest is Test {
    CallBreakerHarness public callbreaker;

    function setUp() public {
        callbreaker = new CallBreakerHarness();
    }

    // TODO / NotImplemented: Add more unit tests
}
