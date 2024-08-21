// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "src/utilities/Faucet.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployFaucet is Script {
    function run() external returns (address, address) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the upgradeable contract
        address _proxyAddress = Upgrades.deployTransparentProxy(
            "Faucet.sol",
            msg.sender,
            abi.encodeCall(Faucet.initialize, ())
        );

        // Get the implementation address
        address implementationAddress = Upgrades.getImplementationAddress(
            _proxyAddress
        );

        vm.stopBroadcast();

        return (implementationAddress, _proxyAddress);
    }
}