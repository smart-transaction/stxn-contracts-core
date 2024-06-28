// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.2 <0.9.0;

import "../../src/timetravel/CallBreaker.sol";

contract PartialFunctionApplication {
    address private _callbreakerAddress;

    address[] private addrlist;
    // TODO: The provided value can be from either this oracle or another oracle
    uint256 private _input;

    constructor(address callbreakerLocation, uint256 input) {
        _callbreakerAddress = callbreakerLocation;
        _input = input;
    }

    // Normal addition
    function add(uint256 input1, uint256 input2) external pure returns (uint256) {
        return input1 + input2;
    }

    function add(uint256 input1, address partialFunctionAddress) external view returns (uint256) {
        PartialFunctionApplication partialFunction = PartialFunctionApplication(partialFunctionAddress);
        uint256 partialValue = partialFunction.add(input1);
        return partialValue;
    }

    function add(uint256 input) external view returns (uint256) {
        return input + _input;
    }

    // Partial function application addition: solve at MEVTime, get the correct arg from the data store
    // Users would enforce invariants on what the correct arg should be
    function add() external view returns (uint256 index) {
        // Get a hint index (hintdex) from the solver, likely computed off-chain, where the correct object is.
        bytes32 hintKey = keccak256(abi.encodePacked("add_arg"));
        bytes memory hintBytes = CallBreaker(payable(_callbreakerAddress)).fetchFromAssociatedDataStore(hintKey);
        
        uint256 returnedvalue = abi.decode(hintBytes, (uint256));
        require(returnedvalue >= 5 && returnedvalue <= 10, "hintKey value must be between 5 and 10");

        return returnedvalue + _input;
    }
}
