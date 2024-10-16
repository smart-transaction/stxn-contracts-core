// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";

interface ILaminator {
    enum DATATYPE {
        INT256,
        UINT256,
        STRING,
        ADDRESS,
        BYTES,
        BYTES32
    }

    struct AdditionalData {
        string name;
        DATATYPE datatype;
        string value;
    }

    /// @notice Calls the `push` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided calldata and calls it into the `push` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param cData The calldata to be pushed.
    /// @param delay The delay for when the call can be executed.
    /// @param selector code identifier for solvers to select relevant actions
    /// @param dataValues to be used by solvers in serving the user objective
    /// @return sequenceNumber The sequence number of the deferred function call.
    function pushToProxy(bytes calldata cData, uint32 delay, bytes32 selector, AdditionalData[] memory dataValues)
        external
        returns (uint256 sequenceNumber);
}
