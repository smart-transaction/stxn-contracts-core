// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/LimitOrder.sol";
import "../test/solve-lib/FlashLiquidityExample.sol";

contract FlashLiquidityTest is Test, FlashLiquidityExampleLib {
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

    function testFlashLiquidity() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand(100000000000000000000, 10, 1);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        solverLand(1000, laminatorSequenceNumber, 1, filler);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }

    function testFlashLiquiditySlippage() public {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand(100000000000000000000, 10, 1);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        vm.expectRevert();
        solverLand(0, laminatorSequenceNumber, 1, filler); // No liquidity provided
        vm.stopPrank();
    }
}
