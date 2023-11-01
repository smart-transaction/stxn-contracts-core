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

    event DebugLog(string message);

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

    function test_run1CronTwo() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        emit DebugLog("kms0");
        laminatorSequenceNumber = userLand();
        emit DebugLog("kms0.5");
        vm.stopPrank();

        uint256 initialFillerBalance = address(filler).balance;

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        emit DebugLog("kms1");

        solverLand(laminatorSequenceNumber, filler);
        emit DebugLog("kms2");

        vm.stopPrank();

        vm.roll(block.number + 8000);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumber, filler);
        vm.stopPrank();

        assertEq(counter.getCount(pusherLaminated), 2);
        assertEq(address(filler).balance, initialFillerBalance + 2 * 100000000000000000);

        assertFalse(callbreaker.isPortalOpen());

        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assertEq(init, false);
    }
}
