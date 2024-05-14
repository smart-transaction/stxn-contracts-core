// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CallBreaker} from "../src/timetravel/CallBreaker.sol";
import {BaseDeployer} from "./BaseDeployer.s.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployCallBreaker is Script, BaseDeployer {
    /// @dev Compute the CREATE2 address for CallBreaker contract.
    /// @param salt The salt for the CallBreaker contract.
    modifier computeCreate2(bytes32 salt) {
        _create2addrCounter = computeCreate2Address(salt, hashInitCode(type(CallBreaker).creationCode));

        _;
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function createDeployMultichain(Chains[] memory deployForks) internal override computeCreate2(_counterSalt) {
        console2.log("CallBreaker create2 address:", _create2addrCounter, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying CallBreaker to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            _chainDeployCallBreaker();

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Function to perform actual deployment.
    function _chainDeployCallBreaker() private broadcast(_deployerPrivateKey) {
        CallBreaker callBreaker = new CallBreaker{salt: _counterSalt}();

        require(_create2addrCounter == address(callBreaker), "Address mismatch CallBreaker");

        console2.log("CallBreaker deployed at address:", address(callBreaker), "\n");
    }
}
