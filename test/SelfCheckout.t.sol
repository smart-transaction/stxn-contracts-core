// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "test/examples/DeFi/SelfCheckout.sol";
import "test/examples/MyErc20.sol";
import "test/solve-lib/DeFi/SelfCheckoutLib.sol";

contract SelfCheckoutTest is Test, SelfCheckoutLib {
    address deployer;
    address pusher;
    address filler;

    function setUp() external {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        // give the pusher some eth
        vm.deal(pusher, 100 ether);

        // start deployer land
        vm.startPrank(deployer);
        deployerLand(pusher, filler);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function test_selfCheckout() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher, pusher);
        laminatorSequenceNumber = userLand();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler, filler);
        solverLand(laminatorSequenceNumber, filler, 20);
        vm.stopPrank();

        assertEq(erc20a.balanceOf(pusherLaminated), 0);
        assertEq(erc20b.balanceOf(pusherLaminated), 20);
        assertEq(erc20a.balanceOf(filler), 10);
        assertEq(erc20b.balanceOf(filler), 0);
        assertFalse(callbreaker.isPortalOpen());

        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }
}
