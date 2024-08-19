// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";

/* solhint-disable max-states-count */
abstract contract BaseDeployer is Script {
    bytes32 internal _salt;

    uint256 internal _deployerPrivateKey;

    address internal _ownerAddress;
    address internal _create2addr;

    enum Chains {
        LocalGoerli,
        LocalFuji,
        LocalBSCTest,
        Amoy,
        BscTest,
        Fuji,
        ArbitrumSepolia,
        OptimismSepolia,
        Moonriver,
        Shiden,
        Ethereum,
        Polygon,
        Bsc,
        Avalanche,
        Arbitrum,
        Optimism,
        Moonbeam,
        Astar,
        Sepolia,
        Base,
        BaseSepolia,
        Lestnet,
        LocalChain
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
        } else if (cycle == Cycle.Test) {
            _deployerPrivateKey = vm.envUint("TEST_DEPLOYER_KEY");
        } else {
            _deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
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
        forks[Chains.LocalChain] = vm.envString("LOCAL_CHAIN_RPC");

        // Testnet
        forks[Chains.Amoy] = vm.envString("AMOY_RPC");
        forks[Chains.BscTest] = vm.envString("BSC_TEST_RPC");
        forks[Chains.Fuji] = vm.envString("FUJI_RPC");
        forks[Chains.ArbitrumSepolia] = vm.envString("ARBITRUM_SEPOLIA_RPC");
        forks[Chains.OptimismSepolia] = vm.envString("OPTIMISM_SEPOLIA_RPC");
        forks[Chains.Shiden] = vm.envString("SHIDEN_RPC");
        forks[Chains.Moonriver] = vm.envString("MOONRIVER_RPC");
        forks[Chains.Sepolia] = vm.envString("SEPOLIA_RPC");
        forks[Chains.BaseSepolia] = vm.envString("BASE_SEPOLIA_RPC");
        forks[Chains.Lestnet] = vm.envString("LESTNET_RPC");

        // Mainnet
        forks[Chains.Ethereum] = vm.envString("ETHEREUM_RPC");
        forks[Chains.Polygon] = vm.envString("POLYGON_RPC");
        forks[Chains.Bsc] = vm.envString("BSC_RPC");
        forks[Chains.Avalanche] = vm.envString("AVALANCE_RPC");
        forks[Chains.Arbitrum] = vm.envString("ARBITRUM_RPC");
        forks[Chains.Optimism] = vm.envString("OPTIMISM_RPC");
        forks[Chains.Moonbeam] = vm.envString("MOONBEAM_RPC");
        forks[Chains.Astar] = vm.envString("ASTAR_RPC");
        forks[Chains.Base] = vm.envString("BASE_RPC");
    }

    function createFork(Chains chain) public {
        vm.createFork(forks[chain]);
    }

    function createSelectFork(Chains chain) public {
        vm.createSelectFork(forks[chain]);
    }

    /// @dev Deploy contracts to mainnet.
    function deployMainnet() external setEnvDeploy(Cycle.Prod) returns (address deploymentAddress) {
        Chains[] memory deployForks = new Chains[](9);

        _salt = bytes32(uint256(10));

        deployForks[0] = Chains.Ethereum;
        deployForks[1] = Chains.Polygon;
        deployForks[2] = Chains.Bsc;
        deployForks[3] = Chains.Avalanche;
        deployForks[4] = Chains.Arbitrum;
        deployForks[5] = Chains.Optimism;
        deployForks[6] = Chains.Moonbeam;
        deployForks[7] = Chains.Astar;
        deployForks[8] = Chains.Base;

        deploymentAddress = createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to testnet.
    function deployTestnet(uint256 counterSalt) public setEnvDeploy(Cycle.Test) returns (address deploymentAddress) {
        Chains[] memory deployForks = new Chains[](5);

        _salt = bytes32(counterSalt);

        deployForks[0] = Chains.Amoy;
        deployForks[1] = Chains.ArbitrumSepolia;
        deployForks[2] = Chains.OptimismSepolia;
        deployForks[3] = Chains.Sepolia;
        deployForks[4] = Chains.BaseSepolia;
        deployForks[5] = Chains.Lestnet;

        deploymentAddress = createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to lestnet.
    function deployLestnet() external setEnvDeploy(Cycle.Dev) returns (address deploymentAddress) {
        Chains[] memory deployForks = new Chains[](1);
        _salt = bytes32(uint256(1));

        deployForks[0] = Chains.Lestnet;

        deploymentAddress = createDeployMultichain(deployForks);
    }

    /// @dev Deploy contracts to selected chains.
    /// @param salt The salt for the SmarterContract contract.
    /// @param deployForks The chains to deploy to.
    /// @param cycle The development cycle to set env variables (dev, test, prod).
    function deploySelectedChains(uint256 salt, Chains[] calldata deployForks, Cycle cycle)
        external
        setEnvDeploy(cycle)
        returns (address deploymentAddress)
    {
        _salt = bytes32(salt);

        deploymentAddress = createDeployMultichain(deployForks);
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function createDeployMultichain(Chains[] memory deployForks) internal virtual returns (address);
}
