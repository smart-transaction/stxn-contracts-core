// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {CallBreaker} from "../src/timetravel/CallBreaker.sol";

import {BaseDeployer} from "./BaseDeployer.s.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployCallBreaker is Script, BaseDeployer {
    address private _create2addrCallBreaker;
    CallBreaker private _callBreaker;

    /// @dev Compute the CREATE2 address for CallBreaker contract.
    /// @param salt The salt for the CallBreaker contract.
    modifier computeCreate2(bytes32 salt) {
        _create2addrCallBreaker = computeCreate2Address(
            salt,
            hashInitCode(type(CallBreaker).creationCode)
        );

        _;
    }

    /// @dev Deploy contracts to mainnet.
    function deployCounterMainnet() external setEnvDeploy(Cycle.Prod) {
        Chains[] memory deployForks = new Chains[](8);

        counterSalt = bytes32(uint256(10));

        deployForks[0] = Chains.Etherum;
        deployForks[1] = Chains.Polygon;
        deployForks[2] = Chains.Bsc;
        deployForks[3] = Chains.Avalanche;
        deployForks[4] = Chains.Arbitrum;
        deployForks[5] = Chains.Optimism;
        deployForks[6] = Chains.Moonbeam;
        deployForks[7] = Chains.Astar;

        createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to testnet.
    function deployCounterTestnet(
        uint256 _counterSalt
    ) public setEnvDeploy(Cycle.Test) {
        Chains[] memory deployForks = new Chains[](8);

        counterSalt = bytes32(_counterSalt);

        deployForks[0] = Chains.Goerli;
        deployForks[1] = Chains.Mumbai;
        deployForks[2] = Chains.BscTest;
        deployForks[3] = Chains.Fuji;
        deployForks[4] = Chains.ArbitrumGoerli;
        deployForks[5] = Chains.OptimismGoerli;
        deployForks[6] = Chains.Shiden;
        deployForks[7] = Chains.Moonriver;

        createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to local.
    function deployCounterLocal() external setEnvDeploy(Cycle.Dev) {
        Chains[] memory deployForks = new Chains[](3);
        counterSalt = bytes32(uint256(1));

        deployForks[0] = Chains.LocalGoerli;
        deployForks[1] = Chains.LocalFuji;
        deployForks[2] = Chains.LocalBSCTest;

        createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to selected chains.
    /// @param _counterSalt The salt for the counter contract.
    /// @param deployForks The chains to deploy to.
    /// @param cycle The development cycle to set env variables (dev, test, prod).
    function deployCounterSelectedChains(
        uint256 _counterSalt,
        Chains[] calldata deployForks,
        Cycle cycle
    ) external setEnvDeploy(cycle) {
        counterSalt = bytes32(_counterSalt);

        createDeployMultichain(deployForks);
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function _createDeployMultichain(
        Chains[] memory deployForks
    ) private computeCreate2(counterSalt) {
        console2.log("Counter create2 address:", create2addrCounter, "\n");

        for (uint256 i; i < deployForks.length; ) {
            console2.log("Deploying Counter to chain: ", uint(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeployCounter();

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Function to perform actual deployment.
    function _chainDeployCallBreaker() private broadcast(deployerPrivateKey) {
        CallBreaker callBreaker = new CallBreaker{salt: counterSalt}();

        require(create2addrCallBreaker == address(callBreaker), "Address mismatch CallBreaker");

        console2.log("Computed CallBreaker address:", address(callBreaker), "\n");

        _callBreaker = CallBreaker(callBreaker);

        console2.log("CallBreaker deployed at address:", address(_callBreaker), "\n");
    }
}
