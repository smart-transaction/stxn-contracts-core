// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {MEVTimeCompute} from "test/examples/MEVOracle/MEVTimeCompute.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployMEVTimeCompute is Script, BaseDeployer {
    address private _callBreaker;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the MEVTimeCompute contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        // passing 8 as a random divisor value for this example, can be updated with setters
        _create2addr =
            computeCreate2Address(salt, hashInitCode(type(MEVTimeCompute).creationCode, abi.encode(_callBreaker, 8)));

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
        console2.log("MEVTimeCompute create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying MEVTimeCompute to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeploySmartedContract();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function chainDeploySmartedContract() private broadcast(_deployerPrivateKey) {
        // passing 8 as a random divisor value for this example, can be updated with setters
        address mevTimeCompute = address(new MEVTimeCompute{salt: _salt}(_callBreaker, 8));

        require(_create2addr == mevTimeCompute, "Address mismatch MEVTimeCompute");

        console2.log("MEVTimeCompute contract deployed at address:", mevTimeCompute, "\n");
    }
}
