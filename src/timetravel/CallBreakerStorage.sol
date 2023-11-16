// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../interfaces/ICallBreaker.sol";

struct ReturnObjectWithIndex {
    ReturnObject returnObj;
    uint256 index;
}

struct AssociatedData {
    bool set;
    bytes value;
}

// allow solver to provide indices where a call is executed, verified for accuracy on chain, to save gas
// this is NOT necessarily complete- to get a complete index of everywhere a call is executed, you need to use getCompleteCallIndex
// getCompleteCallIndex is O(n) and iterates through the entire call list.
struct Hintdex {
    bool set;
    uint256[] indices;
}

struct Call {
    bytes32 callId;
    uint256 index;
}

abstract contract CallBreakerStorage {
    /// @notice Error thrown when calling a function that can only be called when the portal is open
    /// @dev Selector 0x59f0d709
    error PortalClosed();

    /// @notice Error thrown when calling a function that can only be called when the portal is closed
    /// @dev Selector 0x665c980e
    error PortalOpen();

    /// @notice The slot at which the portal status is stored
    bytes32 public constant PORTAL_SLOT = bytes32(uint256(keccak256("CallBreakerStorage.PORTAL_SLOT")) - 1);

    /// @notice The slot at which the call currently being verified is stored
    bytes32 public constant EXECUTING_CALL_INDEX_SLOT =
        bytes32(uint256(keccak256("LaminatorStorage.EXEC_CALL_INDEX_SLOT")) - 1);

    CallObject[] public callStore;
    ReturnObject[] public returnStore;

    bytes32[] public associatedDataKeyList;
    mapping(bytes32 => AssociatedData) public associatedDataStore;

    bytes32[] public hintdicesStoreKeyList;
    mapping(bytes32 => Hintdex) public hintdicesStore;

    Call[] public callList;

    /// @notice Guards calls to functions that can only be called when the portal is open
    modifier onlyPortalOpen() {
        if (!isPortalOpen()) {
            revert PortalClosed();
        }
        _;
    }

    /// @notice Prevents reentrant calls to functions that can only be called when the portal is closed
    modifier onlyPortalClosed() {
        if (isPortalOpen()) {
            revert PortalOpen();
        }
        _setPortalOpen();
        _;
        _setPortalClosed();
    }

    /// @notice Get the portal status
    function isPortalOpen() public view returns (bool status) {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly ("memory-safe") {
            status := sload(slot)
        }
    }

    /// @notice Returns the index number of the currently executing call.
    /// @return _execCallIndex The sequence number of the currently executing call.
    function executingCallIndex() public view returns (uint256 _execCallIndex) {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            _execCallIndex := sload(slot)
        }
    }

    /// @notice Set the portal status to open
    function _setPortalOpen() internal {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 1)
        }
    }

    /// @notice Set the portal status to closed
    function _setPortalClosed() internal {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 0)
        }
    }

    /// @notice Sets the index of the currently executing call.
    /// @dev This function should only be called while a call in deferredCalls is being executed.
    function _setCurrentlyExecutingCallIndex(uint256 _callIndex) internal {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            sstore(slot, _callIndex)
        }
    }
}
