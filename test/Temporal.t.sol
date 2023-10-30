// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./solve-lib/TemporalExample.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/SelfCheckout.sol";
import "../test/examples/MyErc20.sol";

contract TemporalExampleTest is Test, TemporalExampleLib {
    address deployer;
    address pusher;
    address filler;

    function setUp() external {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        // start deployer land
        vm.startPrank(deployer);
        deployerLand(pusher);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    // All of the following tests are `testFail` to conform to `Kontrol` framework standards.
    function test_temporal_run() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 2);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumber, filler);
        vm.stopPrank();

        assertEq(erc20a.balanceOf(filler), 10);
        assertEq(!callbreaker.isPortalOpen(), true);

        (bool init, CallObjectWithDelegateCall[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assertEq(init, false);
    }

    function testFail_run_at_wrong_time() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher); laminatorSequenceNumber = userLand(); vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler); solverLand(laminatorSequenceNumber, filler); vm.stopPrank();
    }
}
