// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "../CallBreakerTypes.sol";
import "../interfaces/ICallBreaker.sol";

abstract contract CallBreakerStorage {
    /// @notice Emitted when the enterPortal function is called
    /// @param calls The CallObject instance containing details of the call
    /// @param returnValues The ReturnObject instance containing details of the return value
    event EnterPortal(CallObject[] calls, ReturnObject[] returnValues);

    /// @notice Error thrown when calling a function that can only be called when the portal is open
    /// @dev Selector 0x59f0d709
    error PortalClosed();

    /// @notice Error thrown when calling a function that can only be called when the portal is closed
    /// @dev Selector 0x665c980e
    error PortalOpen();

    /// @dev Error thrown when key already exists in the associatedDataStore
    /// @dev Selector 0xaa1ba2f8
    error KeyAlreadyExists();

    /// @notice Emitted when a new key-value pair is inserted into the associatedDataStore
    event InsertIntoAssociatedDataStore(bytes32 key, bytes value);

    /// @notice The slot at which the portal status is stored
    bytes32 public constant PORTAL_SLOT = bytes32(uint256(keccak256("CallBreakerStorage.PORTAL_SLOT")) - 1);

    /// @notice The slot at which the call currently being verified is stored
    bytes32 public constant EXECUTING_CALL_INDEX_SLOT =
        bytes32(uint256(keccak256("LaminatorStorage.EXEC_CALL_INDEX_SLOT")) - 1);

    CallObjectStorage[] public callStore;
    ReturnObject[] public returnStore;

    bytes32[] public associatedDataKeyList;
    mapping(bytes32 => bytes) public associatedDataStore;

    bytes32[] public hintdicesStoreKeyList;
    mapping(bytes32 => uint256[]) public hintdicesStore;

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
        _;
    }

    /// @notice Get the portal status
    function isPortalOpen() public view returns (bool status) {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly {
            status := tload(slot)
        }
    }

    /// @notice Returns the index number of the currently executing call.
    /// @return _execCallIndex The sequence number of the currently executing call.
    function _executingCallIndex() internal view returns (uint256 _execCallIndex) {
        uint256 slot = uint256(EXECUTING_CALL_INDEX_SLOT);
        assembly ("memory-safe") {
            _execCallIndex := sload(slot)
        }
    }

    /// @notice Set the portal status to open
    function _setPortalOpen(CallObject[] memory calls, ReturnObject[] memory returnValues) internal {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly {
            tstore(slot, true)
        }
        emit EnterPortal(calls, returnValues);
    }

    /// @notice Set the portal status to closed
    function _setPortalClosed() internal {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly {
            tstore(slot, false)
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

    /// @dev Cleans up storage by resetting all stores
    function _cleanUpStorage() internal {
        delete callStore;
        delete returnStore;
        delete callList;
        for (uint256 i = 0; i < associatedDataKeyList.length; i++) {
            delete associatedDataStore[associatedDataKeyList[i]];
        }
        delete associatedDataKeyList;

        for (uint256 i = 0; i < hintdicesStoreKeyList.length; i++) {
            delete hintdicesStore[hintdicesStoreKeyList[i]];
        }
        delete hintdicesStoreKeyList;

        // Transfer remaining ETH balance to the block builder
        if (address(this).balance > 0) {
            address payable blockBuilder = payable(block.coinbase);
            blockBuilder.transfer(address(this).balance);
        }
    }

    /// @dev Helper function to fetch and remove the last ReturnObject from the storage
    /// @param index The index of the ReturnObject to be fetched
    /// @return _returnObj The last ReturnObject in the storage
    function _getReturn(uint256 index) internal view returns (ReturnObject memory _returnObj) {
        return returnStore[index];
    }

    function _getCall(uint256 index) internal view returns (CallObject memory callobj) {
        return callStore[index].load();
    }
}
