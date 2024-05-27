// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/LimitOrder.sol";
import "../test/solve-lib/LimitOrderExample.sol";

contract LimitOrderTest is Test, LimitOrderExampleLib {
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
        deployerLand(pusher);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function testLimitOrder() external {
        // Disable running this test on local -- should run as fork test environment.
        if (block.number == 1) {
            return;
        }
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
