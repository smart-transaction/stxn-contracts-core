// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import "src/timetravel/CallBreaker.sol";

contract PartialFunctionContract {
    address public callbreakerAddress;

    uint256 public initValue;
    uint256 public divisor;

    /**
      @notice This is a basic example of performing a computation with a partial function application
        At solvetime, the solver can provide an additional value via. associatedData, and the contract
        can use that to perform the computation
        Alternatively, the contract can fetch values from other oracles AT SOLVETIME.
        This pattern may be able to be generalized to any function that can be partially applied.
    */
    constructor(address _callbreaker, uint256 _divisor) {
        callbreakerAddress = _callbreaker;
        divisor = _divisor;
    }

    function setInitValue(uint256 _initValue) external {
        initValue = _initValue;
    }

    /** 
     * @notice solve at MEVTime, get the correct arg from the data store
        Users would enforce invariants on what the correct arg should be
    */ 
    function solve() external view returns (uint256 index) {
        // Get a hint index (hintdex) from the solver, likely computed off-chain, where the correct object is.
        bytes32 hintKey = keccak256(abi.encodePacked("solvedValue"));
        bytes memory hintBytes = CallBreaker(payable(callbreakerAddress))
            .fetchFromAssociatedDataStore(hintKey);

        uint256 returnedvalue = abi.decode(hintBytes, (uint256));
        require(
            (returnedvalue + initValue) % divisor == 0,
            "Execution Reverted: Incorrect value provided"
        );

        return returnedvalue + initValue;
    }
}
