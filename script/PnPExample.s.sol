// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/PnP.sol";

// TODO: Needs translation to test / completion
contract PnPExampleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
        uint256 pusherPrivateKey = vm.envUint("PRIVATE_KEY2");
        uint256 fillerPrivateKey = vm.envUint("PRIVATE_KEY3");

        address pusher = vm.addr(pusherPrivateKey);
        address filler = vm.addr(fillerPrivateKey);

        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");

        // start deployer land
        vm.startBroadcast(deployerPrivateKey);

        Laminator laminator = new Laminator();
        CallBreaker callbreaker = new CallBreaker();
        PnP pnp = new PnP(address(callbreaker), pusherPrivateKey);

        // compute the pusher laminated address
        address payable pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        vm.label(address(laminator), "laminator");
        vm.label(address(callbreaker), "callbreaker");
        vm.label(address(pnp), "pnp");
        vm.label(pusherLaminated, "pusherLaminated");

        vm.stopBroadcast();
    }
}
