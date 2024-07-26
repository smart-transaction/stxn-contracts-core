// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "src/timetravel/CallBreaker.sol";
import "test/examples/MEVOracle/MEVTimeCompute.sol";
import "test/solve-lib/MEVTimeOracle/MEVTimeComputeLib.sol";

contract MEVTimeComputeTest is Test, MEVTimeComputeLib {
    address deployer;
    address pusher;
    address filler;

    function setUp() public {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        // give the pusher some eth
        vm.deal(pusher, 100 ether);

        // start deployer land
        vm.startPrank(deployer);
        deployerLand(pusher, 8, 11); // passing 8 as divisor and 11 as init value
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function testMEVTimeCompute() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumber, filler);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }
}
