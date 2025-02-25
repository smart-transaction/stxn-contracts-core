// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {AshToken} from "src/tokens/AshToken.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployAshToken is Script, BaseDeployer {
    address private _ashToken;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the AshToken contract.
    modifier computeCreate2(bytes32 salt) {
        _ashToken = computeCreate2Address(salt, hashInitCode(type(AshToken).creationCode, abi.encode(_ownerAddress)));

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
        console2.log("AshToken create2 address:", _ashToken, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying AshToken to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeployAshToken();

            unchecked {
                ++i;
            }
        }
        return _ashToken;
    }

    /// @dev Function to perform actual deployment.
    function chainDeployAshToken() private broadcast(_deployerPrivateKey) {
        address ashToken = address(new AshToken{salt: _salt}(_ownerAddress));

        require(_ashToken == ashToken, "Address mismatch AshToken");

        console2.log("AshToken deployed at address:", ashToken, "\n");
    }
}
