// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/// @notice not being used since faucet was not deployed using a proxy
contract UpgradeFaucet is Script {
    function run() external returns (address, address) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address proxyAddress = vm.envAddress("PROXY");
        vm.startBroadcast(deployerPrivateKey);
        // Upgrade the upgradeable contract
        Upgrades.upgradeProxy(proxyAddress, "FaucetV1.sol", "");

        // Get the implementation address
        address implementationAddress = Upgrades.getImplementationAddress(proxyAddress);

        vm.stopBroadcast();

        return (implementationAddress, proxyAddress);
    }
}
