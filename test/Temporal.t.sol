// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "./solve-lib/TemporalExample.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/SelfCheckout.sol";
import "../test/examples/MyErc20.sol";

contract TemporalExampleTest is Script, TemporalExampleLib {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
    uint256 pusherPrivateKey = vm.envUint("PRIVATE_KEY2");
    uint256 fillerPrivateKey = vm.envUint("PRIVATE_KEY3");

    address pusher = vm.addr(pusherPrivateKey);
    address filler = vm.addr(fillerPrivateKey);

    function setUp() external {
        // start deployer land
        vm.startBroadcast(deployerPrivateKey); deployerLand(pusher); vm.stopBroadcast();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function test_temporal_run() external {
        uint256 laminatorSequenceNumber;

        vm.startBroadcast(pusherPrivateKey); laminatorSequenceNumber = userLand(); vm.stopBroadcast();

        // go forward in time
        vm.roll(block.number + 2);

        vm.startBroadcast(fillerPrivateKey); solverLand(laminatorSequenceNumber, filler); vm.stopBroadcast();
        
        assert(erc20a.balanceOf(filler) == 10);
        assert(!callbreaker.isPortalOpen());

        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assert(!init);
    }


    function test_run_at_wrong_time() external {
        uint256 laminatorSequenceNumber;

        vm.startBroadcast(pusherPrivateKey); laminatorSequenceNumber = userLand(); vm.stopBroadcast();

        // go forward in time
        vm.roll(block.number + 1);

        // Should revert since the time isn't right
        vm.expectRevert();
        vm.startBroadcast(fillerPrivateKey); solverLand(laminatorSequenceNumber, filler); vm.stopBroadcast();
    }
}