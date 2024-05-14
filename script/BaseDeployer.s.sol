// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";

/* solhint-disable max-states-count */
abstract contract BaseDeployer is Script {
    bytes32 internal _counterProxySalt;
    bytes32 internal _counterSalt;

    uint256 internal _deployerPrivateKey;

    address internal _ownerAddress;
    address internal _proxyCounterAddress;
    address internal _create2addrCounter;

    enum Chains {
        LocalGoerli,
        LocalFuji,
        LocalBSCTest,
        Goerli,
        Mumbai,
        BscTest,
        Fuji,
        ArbitrumGoerli,
        OptimismGoerli,
        Moonriver,
        Shiden,
        Etherum,
        Polygon,
        Bsc,
        Avalanche,
        Arbitrum,
        Optimism,
        Moonbeam,
        Astar
    }

    enum Cycle {
        Dev,
        Test,
        Prod
    }

    /// @dev Mapping of chain enum to rpc url
    mapping(Chains chains => string rpcUrls) public forks;

    /// @dev environment variable setup for deployment
    /// @param cycle deployment cycle (dev, test, prod)
    modifier setEnvDeploy(Cycle cycle) {
        if (cycle == Cycle.Dev) {
            _deployerPrivateKey = vm.envUint("LOCAL_DEPLOYER_KEY");
            _ownerAddress = vm.envAddress("LOCAL_OWNER_ADDRESS");
        } else if (cycle == Cycle.Test) {
            _deployerPrivateKey = vm.envUint("TEST_DEPLOYER_KEY");
            _ownerAddress = vm.envAddress("TEST_OWNER_ADDRESS");
        } else {
            _deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
            _ownerAddress = vm.envAddress("OWNER_ADDRESS");
        }

        _;
    }

    /// @dev environment variable setup for upgrade
    /// @param cycle deployment cycle (dev, test, prod)
    modifier setEnvUpgrade(Cycle cycle) {
        if (cycle == Cycle.Dev) {
            _deployerPrivateKey = vm.envUint("LOCAL_DEPLOYER_KEY");
            _proxyCounterAddress = vm.envAddress("LOCAL_COUNTER_PROXY_ADDRESS");
        } else if (cycle == Cycle.Test) {
            _deployerPrivateKey = vm.envUint("TEST_DEPLOYER_KEY");
            _proxyCounterAddress = vm.envAddress("TEST_COUNTER_PROXY_ADDRESS");
        } else {
            _deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
            _proxyCounterAddress = vm.envAddress("COUNTER_PROXY_ADDRESS");
        }

        _;
    }

    /// @dev broadcast transaction modifier
    /// @param pk private key to broadcast transaction
    modifier broadcast(uint256 pk) {
        vm.startBroadcast(pk);

        _;

        vm.stopBroadcast();
    }

    constructor() {
        // Local
        forks[Chains.LocalGoerli] = "localGoerli";
        forks[Chains.LocalFuji] = "localFuji";
        forks[Chains.LocalBSCTest] = "localBSCTest";

        // Testnet
        forks[Chains.Goerli] = "goerli";
        forks[Chains.Mumbai] = "mumbai";
        forks[Chains.BscTest] = "bsctest";
        forks[Chains.Fuji] = "fuji";
        forks[Chains.ArbitrumGoerli] = "arbitrumgoerli";
        forks[Chains.OptimismGoerli] = "optimismgoerli";
        forks[Chains.Shiden] = "shiden";
        forks[Chains.Moonriver] = "moonriver";
        // @TODO Add Base

        // Mainnet
        forks[Chains.Etherum] = "etherum";
        forks[Chains.Polygon] = "polygon";
        forks[Chains.Bsc] = "bsc";
        forks[Chains.Avalanche] = "avalanche";
        forks[Chains.Arbitrum] = "arbitrum";
        forks[Chains.Optimism] = "optimism";
        forks[Chains.Moonbeam] = "moonbeam";
        forks[Chains.Astar] = "astar";
    }

    function createFork(Chains chain) public {
        vm.createFork(forks[chain]);
    }

    function createSelectFork(Chains chain) public {
        vm.createSelectFork(forks[chain]);
    }

    /// @dev Deploy contracts to mainnet.
    function deployMainnet() external setEnvDeploy(Cycle.Prod) {
        Chains[] memory deployForks = new Chains[](8);

        _counterSalt = bytes32(uint256(10));
        _counterProxySalt = bytes32(uint256(11));

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
    function deployTestnet(uint256 counterSalt) public setEnvDeploy(Cycle.Test) {
        Chains[] memory deployForks = new Chains[](2);

        _counterSalt = bytes32(counterSalt);

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
    function deployLocal() external setEnvDeploy(Cycle.Dev) {
        Chains[] memory deployForks = new Chains[](2);
        _counterSalt = bytes32(uint256(1));
        _counterProxySalt = bytes32(uint256(2));

        deployForks[0] = Chains.LocalGoerli;
        deployForks[1] = Chains.LocalFuji;
        deployForks[2] = Chains.LocalBSCTest;

        createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to selected chains.
    /// @param salt The salt for the SmarterContract contract.
    /// @param deployForks The chains to deploy to.
    /// @param cycle The development cycle to set env variables (dev, test, prod).
    function deploySelectedChains(uint256 salt, Chains[] calldata deployForks, Cycle cycle)
        external
        setEnvDeploy(cycle)
    {
        _counterSalt = bytes32(salt);

        createDeployMultichain(deployForks);
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function createDeployMultichain(Chains[] memory deployForks) internal virtual;
}
