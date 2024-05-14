// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "./BaseDeployer.s.sol";
import {SmarterContract} from "../src/timetravel/SmarterContract.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeploySmarterContract is Script, BaseDeployer {
    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the SmarterContract contract.
    modifier computeCreate2(bytes32 salt) {
        _create2addrCounter = computeCreate2Address(
            salt,
            hashInitCode(type(SmarterContract).creationCode)
        );

        _;
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function createDeployMultichain(
        Chains[] memory deployForks
    ) internal override computeCreate2(_counterSalt) {
        console2.log("SmarterContract create2 address:", _create2addrCounter, "\n");

        for (uint256 i; i < deployForks.length; ) {
            console2.log("Deploying SmarterContract to chain: ", uint(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeploySmartedContract();

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Function to perform actual deployment.
    function chainDeploySmartedContract() private broadcast(_deployerPrivateKey) {
        SmarterContract sc = new SmarterContract{salt: _counterSalt}(vm.envAddress("CALL_BREAKER_ADDRESS"));

        // TODO: fails as of now
        // require(_create2addrCounter == address(sc), "Address mismatch SmarterContract");

        console2.log("SmarterContract deployed at address:", address(sc), "\n");
    }
}