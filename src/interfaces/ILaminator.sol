// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";

interface ILaminator {
    /// @notice Calls the `push` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided calldata and calls it into the `push` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param cData The calldata to be pushed.
    /// @param delay The delay for when the call can be executed.
    /// @return sequenceNumber The sequence number of the deferred function call.
    function pushToProxy(bytes calldata cData, uint32 delay) external returns (uint256 sequenceNumber);

    /// @notice Calls the `pull` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided sequence number and calls it into the `pull` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param sequenceNumber The sequence number of the deferred function call to be pulled.
    function pullFromProxy(uint256 sequenceNumber) external;

    /// @notice Calls the `execute` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided calldata and calls it into the `execute` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param cData The calldata to be executed.
    function executeInProxy(bytes calldata cData) external returns (bytes memory);
}
