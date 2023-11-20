// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./solve-lib/Whitelist.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";

contract WhiteListedTest is Test, Whitelist {
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

    function testWhitelist() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLandWhitelist();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        solverLandWhitelist(laminatorSequenceNumber, filler);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        // Should be cleared so init should be false (testFail format is for compliance with Kontrol framework)
        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }

    //' This is a test that should fail -- @TODO: Assert revert with message custom error c19f17a9: CallFailed()
    function testFail_BlackList() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLandBlackList();
        vm.stopPrank();

        uint256 initialFillerBalance = address(filler).balance;

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        solverLandBlackList(laminatorSequenceNumber, filler);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        // Should be cleared so init should be false (testFail format is for compliance with Kontrol framework)
        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }
}
