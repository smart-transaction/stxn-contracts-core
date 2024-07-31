// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/timetravel/CallBreaker.sol";
import "test/solve-lib/DeFi/SlippageProtectionLib.sol";

contract SlippageProtectionTest is Test, SlippageProtectionLib {
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

    function testSlippageProtection() external {
        uint256 laminatorSequenceNumber;
        uint256 maxSlippage = 10;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand(maxSlippage);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumber, filler, maxSlippage);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }

    function testSlippageProtectionRevert() external {
        uint256 laminatorSequenceNumber;
        uint256 maxSlippage = 1;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand(maxSlippage);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        vm.expectRevert();
        solverLand(laminatorSequenceNumber, filler, maxSlippage);
        vm.stopPrank();
    }
}
