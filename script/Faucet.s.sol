// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "src/utilities/Faucet.sol";
import {BaseDeployer} from "./BaseDeployer.s.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployFaucet is Script, BaseDeployer {
    /// @dev Compute the CREATE2 address for Faucet contract.
    /// @param salt The salt for the Faucet contract.
    modifier computeCreate2(bytes32 salt) {
        _create2addr = computeCreate2Address(salt, hashInitCode(type(Faucet).creationCode));

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
        console2.log("Faucet create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying Faucet to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            _chainDeployCallBreaker();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function _chainDeployCallBreaker() private broadcast(_deployerPrivateKey) {
        Faucet faucet = new Faucet{salt: _salt}();

        require(_create2addr == address(faucet), "Address mismatch Faucet");

        console2.log("Faucet deployed at address:", address(faucet), "\n");
    }
}
