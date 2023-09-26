// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.9.0;

import "../timetravel/CallBreaker.sol";

contract TemporalStates {
    address private _callbreakerAddress;
    constructor(address callbreakerLocation) {
        _callbreakerAddress = callbreakerLocation;
    }

    function entryPoint(uint256 blockTime, bytes memory input) public pure returns (bool) {
        return _rightTime(blockTime) && _isVulnerable(input);
    }

    function timeExploit(uint256 blockTime, bytes memory input) external returns (bool) {
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("timeExploit(uint256,bytes)", blockTime, input)
        });

        // call, hit the fallback.
        (bool success, bytes memory returnvalue) = _callbreakerAddress.call(abi.encode(callObj));

        if (!success) {
            revert("turner CallFailed");
        }

        // this one just returns whatever it gets from the turner.
        return abi.decode(returnvalue, (bool));
    }

    function _rightTime(uint256 blockTime) internal pure returns (bool) {
        return blockTime == 3;
    }

    function _isVulnerable(bytes memory input) internal pure returns (bool) {
        bytes memory vulnString = "vulnerable";
        return keccak256(vulnString) == keccak256(input);
    }
}
