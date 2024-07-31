// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./solve-lib/CronCounterLib.sol";

import "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";

contract CronTest is Test, CronCounterLib {
    address deployer;
    address pusher;
    address filler;

    function setUp() external {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        // give the pusher some eth
        vm.deal(pusher, 100 ether);

        // start deployer calls
        vm.startPrank(deployer);
        deployerLand(pusher);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function testrun1Cron() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand();
        vm.stopPrank();

        uint256 initialFillerBalance = address(filler).balance;

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);

        solverLand(laminatorSequenceNumber, filler, true);

        vm.stopPrank();

        vm.roll(block.number + 8000);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumber, filler, false);
        vm.stopPrank();

        assertEq(counter.getCount(pusherLaminated), 2);
        assertEq(address(filler).balance, initialFillerBalance + 2 * 33);

        assertFalse(callbreaker.isPortalOpen());

        // Should be cleared so init should be false (testFail format is for compliance with Kontrol framework)
        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }
}
