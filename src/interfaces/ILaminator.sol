// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";

interface ILaminator {
    /// @notice Calls the `push` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided calldata and calls it into the `push` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param callObjs The calldatas to be pushed.
    /// @param delay The delay for when the call can be executed.
    /// @param selector code identifier for solvers to select relevant actions
    /// @param dataValues to be used by solvers in serving the user objective
    /// @return sequenceNumber The sequence number of the deferred function call.
    function pushToProxy(CallObject[] memory callObjs, uint32 delay, bytes32 selector, SolverData[] memory dataValues)
        external
        returns (uint256 sequenceNumber);
}
