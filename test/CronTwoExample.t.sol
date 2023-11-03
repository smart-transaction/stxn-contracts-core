// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./solve-lib/CronTwo.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";

contract CronTwoTest is Test, CronTwoLib {
    address deployer;
    address pusher;
    address filler;

    function setUp() external {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        // Mint ether to the deployer
        payable(deployer).transfer(10000000000000000000);

        // start deployer land
        vm.startPrank(deployer);
        deployerLand(pusher);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function testFail_run1CronTwo() external {
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
        assertEq(address(filler).balance, initialFillerBalance + 2 * 100000000000000000);

        assertFalse(callbreaker.isPortalOpen());

        //  Should be cleared so init should be false (testFail format is for compliance with Kontrol framework)
        (bool init,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assertTrue(init);
    }
}
