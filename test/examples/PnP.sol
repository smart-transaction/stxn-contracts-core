// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.9.0;

import "../../src/timetravel/CallBreaker.sol";

contract PnP {
    address private _callbreakerAddress;

    address[] private addrlist;

    constructor(address callbreakerLocation, uint256 input) {
        _callbreakerAddress = callbreakerLocation;
        // populate addrlist with a hash chain to look "random"
        addrlist.push(hash(input));
        for (uint256 i = 1; i < 100000; i++) {
            addrlist.push(hash(addrlist[i - 1]));
        }
    }

    function p(address input, uint256 index) external view returns (bool) {
        if (addrlist[index] == input) {
            return true;
        }
        return false;
    }

    // not np, but linearly searches a huge array rather than constant time
    function np(address input) external view returns (uint256, bool) {
        uint256 index = 0;
        for (uint256 i = 0; i < 100000; i++) {
            if (addrlist[i] == input) {
                return (index, true);
            }
        }
        return (0, false);
    }

    // uses an index hint to find the correct item in the array
    function callBreakerNp(address input) external view returns (uint256 index) {
        // Get a hint index (hintdex) from the solver, likely computed off-chain, where the correct object is.
        bytes32 hintKey = keccak256(abi.encodePacked("hintdex"));
        bytes memory hintBytes = CallBreaker(payable(_callbreakerAddress)).fetchFromAssociatedDataStore(hintKey);

        uint256 returnedvalue = abi.decode(hintBytes, (uint256));

        require(this.p(input, returnedvalue), "callBreakerNp, hint wrong");

        return returnedvalue;
    }

    function hash(uint256 input) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(input)))));
    }

    function hash(address input) public pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(input)))));
    }
}
