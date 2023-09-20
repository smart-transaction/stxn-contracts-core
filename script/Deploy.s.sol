// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";

contract CounterScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Laminator laminator = new Laminator();
        CallBreaker callbreaker = new CallBreaker();

        vm.stopBroadcast();
    }
}