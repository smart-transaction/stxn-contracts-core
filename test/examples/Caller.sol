// SPDX-License-Identifier: UNKNOWN

pragma solidity >=0.6.2 <0.9.0;

import "../../src/timetravel/CallBreaker.sol";
import "../../src/timetravel/SmarterContract.sol";

contract Caller is SmarterContract {
    address private _callbreakerAddress;

    constructor(address callBreaker, address ofacBlocked, address audited) SmarterContract(callBreaker) {
        _callbreakerAddress = callBreaker;
        // Sets the following sample addresses to OFAC blocked and audited to proceed with tests
        ofacCensoredAddresses[ofacBlocked] = true;
        auditedContracts[audited] = true;
    }

    function callWhitelisted(address target, bytes memory callData) public payable onlyAudited(target) {
        (bool success, bytes memory returnData) = target.call{value: msg.value}(callData);
        if (!success) {
            revert(string(returnData));
        }
    }

    function callAnyButBlacklisted(address target, bytes memory callData) public payable onlyOFACApproved(target) {
        (bool success, bytes memory returnData) = target.call{value: msg.value}(callData);
        if (!success) {
            revert(string(returnData));
        }
    }
}
