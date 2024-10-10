// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "./BaseDeployer.s.sol";
import {SmarterContract} from "../src/timetravel/SmarterContract.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeploySmarterContract is Script, BaseDeployer {
    address private _callBreaker;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the SmarterContract contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");
        _create2addr =
            computeCreate2Address(salt, hashInitCode(type(SmarterContract).creationCode, abi.encode(_callBreaker)));

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
        console2.log("SmarterContract create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying SmarterContract to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeploySmarterContract();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function chainDeploySmarterContract() private broadcast(_deployerPrivateKey) {
        SmarterContract sc = new SmarterContract{salt: _salt}(_callBreaker);

        require(_create2addr == address(sc), "Address mismatch SmarterContract");

        console2.log("SmarterContract deployed at address:", address(sc), "\n");
    }
}
