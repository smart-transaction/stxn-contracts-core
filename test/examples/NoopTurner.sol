// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import "../../src/timetravel/CallBreaker.sol";
import "../../src/timetravel/SmarterContract.sol";
import "../../src/TimeTypes.sol";

contract NoopTurner is SmarterContract {
    address private _callbreakerAddress;

    constructor(address callbreakerAddress) SmarterContract(callbreakerAddress) {
        _callbreakerAddress = callbreakerAddress;
    }

    // noop function without callbreaker
    function vanilla(uint16 /* _input */ ) public pure returns (uint16) {
        return 52;
    }

    function const_loop() external view returns (uint16) {
        // this one just returns whatever it gets at solvetime via. associatedDataStore
        uint256 callIndex = CallBreaker(payable(_callbreakerAddress)).getCurrentlyExecuting();

        return abi.decode(CallBreaker(payable(_callbreakerAddress)).getReturnValue(callIndex), (uint16));
    }
}
