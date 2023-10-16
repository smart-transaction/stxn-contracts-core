// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "./solve-lib/CronExample.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/SelfCheckout.sol";
import "../test/examples/MyErc20.sol";

contract CronExampleTest is Script, CronExampleLib {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
    uint256 pusherPrivateKey = vm.envUint("PRIVATE_KEY2");
    uint256 fillerPrivateKey = vm.envUint("PRIVATE_KEY3");

    address pusher = vm.addr(pusherPrivateKey);
    address filler = vm.addr(fillerPrivateKey);
    address deployer = vm.addr(deployerPrivateKey);

    function setUp() external {
        // start deployer land
        vm.startPrank(deployer);
        deployerLand(pusher);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function test_cron_run() external {
        uint256 laminatorSequenceNumberFirst;
        uint256 laminatorSequenceNumberSecond;

        vm.startPrank(pusher);
        (laminatorSequenceNumberFirst, laminatorSequenceNumberSecond) = userLand();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 3);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumberFirst, filler);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 7);

        // Sequence number
        vm.startPrank(filler);
        solverLand(laminatorSequenceNumberSecond, filler);
        vm.stopPrank();

        assert(erc20a.balanceOf(filler) == 10);
        assert(!callbreaker.isPortalOpen());

        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumberFirst);
        assert(!init);

        (bool initSecond, CallObject[] memory coSecond) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumberSecond);
        assert(!initSecond);
    }
}
