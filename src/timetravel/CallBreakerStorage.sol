// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../interfaces/ICallBreaker.sol";

abstract contract CallBreakerStorage {
    /// @notice Error thrown when calling a function that can only be called when the portal is open
    /// @dev Selector 0x59f0d709
    error PortalClosed();

    /// @notice Error thrown when calling a function that can only be called when the portal is closed
    /// @dev Selector 0x665c980e
    error PortalOpen();

    /// @notice The slot at which the portal status is stored
    bytes32 public constant PORTAL_SLOT = bytes32(uint256(keccak256("CallBreakerStorage.PORTAL_SLOT")) - 1);

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
}
