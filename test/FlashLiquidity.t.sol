// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/lamination/LaminatedProxy.sol";
import "test/solve-lib/DeFi/FlashLiquidityLib.sol";

contract FlashLiquidityTest is Test, FlashLiquidityLib {
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

        vm.startPrank(pusher, pusher);
        laminatorSequenceNumber = userLand(10000 * 1e18, 10000, 2);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler, filler);
        solverLand(1000000000, 10000, laminatorSequenceNumber, 2, filler);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        (bool init, bool exec,,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }

    function testFlashLiquiditySlippage() public {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher, pusher);
        laminatorSequenceNumber = userLand(10000 * 1e18, 80000, 2);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler, filler);
        vm.expectRevert();
        solverLand(0, 0, laminatorSequenceNumber, 1, filler); // No liquidity provided
        vm.stopPrank();
    }
}
