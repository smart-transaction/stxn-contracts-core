// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "../CallBreakerTypes.sol";
import "../interfaces/ICallBreaker.sol";

abstract contract CallBreakerStorage {
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
    mapping(bytes32 => AssociatedDataStorage) public associatedDataStore;

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
    function _setPortalOpen() internal {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly {
            tstore(slot, true)
        }
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

    /// @notice Inserts a key-value pair into the hintdicesStore and hintdicesStoreKeyList
    /// @dev If the key doesn't exist in the hintdicesStore, it initializes it
    /// @param key The key to be inserted into the hintdicesStore
    /// @param value The value to be associated with the key in the hintdicesStore
    function _insertIntoHintdices(bytes32 key, uint256 value) internal {
        // If the key doesn't exist in the hintdices, initialize it
        if (!hintdicesStore[key].set) {
            hintdicesStore[key].set = true;
            hintdicesStore[key].indices = new uint256[](0);
            hintdicesStoreKeyList.push(key);
        }

        // Append the value to the list of values associated with the key
        hintdicesStore[key].indices.push(value);
    }

    /// @notice Inserts a pair of bytes32 into the associatedDataStore and associatedDataKeyList
    /// @param key The key to be inserted into the associatedDataStore
    /// @param value The value to be associated with the key in the associatedDataStore
    function _insertIntoAssociatedDataStore(bytes32 key, bytes memory value) internal {
        // Check if the key already exists in the associatedDataStore
        if (associatedDataStore[key].set()) {
            revert KeyAlreadyExists();
        }

        emit InsertIntoAssociatedDataStore(key, value);
        // Insert the key-value pair into the associatedDataStore
        associatedDataStore[key].store(value);

        // Add the key to the associatedDataKeyList
        associatedDataKeyList.push(key);
    }

    /// @dev Cleans up storage by resetting all stores
    function _cleanUpStorage() internal {
        delete callStore;
        delete returnStore;
        delete callList;
        for (uint256 i = 0; i < associatedDataKeyList.length; i++) {
            associatedDataStore[associatedDataKeyList[i]].wipe();
        }
        delete associatedDataKeyList;

        for (uint256 i = 0; i < hintdicesStoreKeyList.length; i++) {
            delete hintdicesStore[hintdicesStoreKeyList[i]];
        }
        delete hintdicesStoreKeyList;

        // Transfer remaining ETH balance to the block builder
        address payable blockBuilder = payable(block.coinbase);
        blockBuilder.transfer(address(this).balance);
    }

    /// @dev Resets the trace stores with the provided calls and return values.
    /// @param calls An array of CallObject to be stored in callStore.
    /// @param returnValues An array of ReturnObject to be stored in returnStore.
    function _resetTraceStoresWith(CallObject[] memory calls, ReturnObject[] memory returnValues) internal {
        delete callStore;
        delete returnStore;
        for (uint256 i = 0; i < calls.length; i++) {
            callStore.push().store(calls[i]);
            returnStore.push(returnValues[i]);
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
