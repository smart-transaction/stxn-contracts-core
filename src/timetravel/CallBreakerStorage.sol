// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../interfaces/ICallBreaker.sol";

abstract contract CallBreakerStorage {
    error PortalClosed();

    bytes32 public constant PORTAL_SLOT = bytes32(uint256(keccak256("CallBreakerStorage.PORTAL_SLOT")) - 1);

    modifier onlyPortalOpen() {
        if (!isPortalOpen()) {
            revert PortalClosed();
        }
        _;
    }

    function isPortalOpen() public view returns (bool status) {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly ("memory-safe") {
            status := sload(slot)
        }
    }

    function _setPortalOpen() internal {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 1)
        }
    }

    function _setPortalClosed() internal {
        uint256 slot = uint256(PORTAL_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 0)
        }
    }
}