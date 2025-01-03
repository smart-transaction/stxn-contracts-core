// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {CallBreaker, CallObject, ReturnObject} from "src/timetravel/CallBreaker.sol";
import "src/CallBreakerTypes.sol";

contract CallBreakerHarness is CallBreaker {
    function setPortalOpen(CallObject[] memory calls, ReturnObject[] memory returnValues) public {
        _setPortalOpen(calls, returnValues);
    }

    function populateCallIndicesHarness() public {
        _populateCallIndices();
    }

    function resetTraceStoresWithHarness(CallObject[] memory calls, ReturnObject[] memory returnValues) public {
        delete callStore;
        delete returnStore;
        _populateCallsAndReturnValues(calls, returnValues);
    }

    function _executeAndVerifyCallHarness(uint256 index) public {
        _setCurrentlyExecutingCallIndex(index);
        _executeAndVerifyCall(index);
    }

    function cleanUpStorageHarness() public {
        _cleanUpStorage();
    }

    function populateAssociatedDataStoreHarness(AdditionalData[] memory associatedData) public {
        _populateAssociatedDataStore(associatedData);
    }

    function insertIntoHintdicesHarness(bytes32 key, uint256 value) public {
        hintdicesStore[key].push(value);
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
