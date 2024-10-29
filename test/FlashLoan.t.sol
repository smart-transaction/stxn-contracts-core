// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/lamination/LaminatedProxy.sol";
import "test/solve-lib/DeFi/FlashLoanLib.sol";

contract FlashLoanTest is Test, FlashLoanLib {
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

    function testFlashLoan() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher, pusher);
        laminatorSequenceNumber = userLand(100000000000000000000, 10, 2);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler, filler);
        solverLand(1000, 100, laminatorSequenceNumber, 2, filler);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }
}
