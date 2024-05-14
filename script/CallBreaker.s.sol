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
        _create2addrCounter = computeCreate2Address(
            salt,
            hashInitCode(type(CallBreaker).creationCode)
        );

        _;
    }

    /// @dev Deploy contracts to mainnet.
    function deployMainnet() external setEnvDeploy(Cycle.Prod) {
        Chains[] memory deployForks = new Chains[](8);

        _counterSalt = bytes32(uint256(10));

        deployForks[0] = Chains.Etherum;
        deployForks[1] = Chains.Polygon;
        deployForks[2] = Chains.Bsc;
        deployForks[3] = Chains.Avalanche;
        deployForks[4] = Chains.Arbitrum;
        deployForks[5] = Chains.Optimism;
        deployForks[6] = Chains.Moonbeam;
        deployForks[7] = Chains.Astar;

        _createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to testnet.
    function deployTestnet(
        uint256 salt
    ) public setEnvDeploy(Cycle.Test) {
        Chains[] memory deployForks = new Chains[](8);

        _counterSalt = bytes32(salt);

        deployForks[0] = Chains.Goerli;
        deployForks[1] = Chains.Mumbai;
        deployForks[2] = Chains.BscTest;
        deployForks[3] = Chains.Fuji;
        deployForks[4] = Chains.ArbitrumGoerli;
        deployForks[5] = Chains.OptimismGoerli;
        deployForks[6] = Chains.Shiden;
        deployForks[7] = Chains.Moonriver;

        _createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to local.
    function deployLocal() external setEnvDeploy(Cycle.Dev) {
        Chains[] memory deployForks = new Chains[](3);
        _counterSalt = bytes32(uint256(1));

        deployForks[0] = Chains.LocalGoerli;
        deployForks[1] = Chains.LocalFuji;
        deployForks[2] = Chains.LocalBSCTest;

        _createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to selected chains.
    /// @param salt The salt for the counter contract.
    /// @param deployForks The chains to deploy to.
    /// @param cycle The development cycle to set env variables (dev, test, prod).
    function deploySelectedChains(
        uint256 salt,
        Chains[] calldata deployForks,
        Cycle cycle
    ) external setEnvDeploy(cycle) {
        _counterSalt = bytes32(salt);

        _createDeployMultichain(deployForks);
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function _createDeployMultichain(
        Chains[] memory deployForks
    ) private computeCreate2(_counterSalt) {
        console2.log("CallBreaker create2 address:", _create2addrCounter, "\n");

        for (uint256 i; i < deployForks.length; ) {
            console2.log("Deploying CallBreaker to chain: ", uint(deployForks[i]), "\n");

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
