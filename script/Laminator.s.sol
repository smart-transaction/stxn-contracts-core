// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

import {BaseDeployer} from "./BaseDeployer.s.sol";
import {Laminator} from "../src/lamination/Laminator.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployLaminator is Script, BaseDeployer {
    address private _callBreaker;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the Laminator contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");
        _create2addr = computeCreate2Address(salt, hashInitCode(type(Laminator).creationCode, abi.encode(_callBreaker)));

        _;
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    /// @return address of the deployed contract
    function createDeployMultichain(Chains[] memory deployForks)
        internal
        override
        computeCreate2(_salt)
        returns (address)
    {
        console2.log("Laminator create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying Laminator to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeployLaminator();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function chainDeployLaminator() private broadcast(_deployerPrivateKey) {
        Laminator counter = new Laminator{salt: _salt}(_callBreaker);

        require(_create2addr == address(counter), "Address mismatch Laminator");

        console2.log("Laminator deployed at address:", address(counter), "\n");
    }
}
