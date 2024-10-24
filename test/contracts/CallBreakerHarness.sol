// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {CallBreaker, CallObject, ReturnObject} from "src/timetravel/CallBreaker.sol";

contract CallBreakerHarness is CallBreaker {
    function setPortalOpen() public {
        _setPortalOpen();
    }

    function populateCallIndicesHarness() public {
        _populateCallIndices();
    }

    function resetTraceStoresWithHarness(CallObject[] memory calls, ReturnObject[] memory returnValues) public {
        _resetTraceStoresWith(calls, returnValues);
    }

    function _executeAndVerifyCallHarness(uint256 index) public {
        _setCurrentlyExecutingCallIndex(index);
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
        hintdicesStore[key] = abi.encode(value);
    }

    function insertIntoAssociatedDataStore(bytes32 key, bytes memory value) public {
        associatedDataStore[key] = value;
    }

    function expectCallAtHarness(CallObject memory callObj, uint256 index) public view {
        _expectCallAt(callObj, index);
    }

    function getCallStoreLengthHarness() public view returns (uint256) {
        return callStore.length;
    }

    function getReturnStoreLengthHarness() public view returns (uint256) {
        return returnStore.length;
    }

    function getCallListLengthHarness() public view returns (uint256) {
        return callList.length;
    }

    function getAssociatedDataKeyListLengthHarness() public view returns (uint256) {
        return associatedDataKeyList.length;
    }

    function getHintdicesStoreKeyListLengthHarness() public view returns (uint256) {
        return hintdicesStoreKeyList.length;
    }
}
