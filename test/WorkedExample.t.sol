// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./solve-lib/WorkedExample.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/SelfCheckout.sol";
import "../test/examples/MyErc20.sol";

contract WorkedExampleTest is Test, WorkedExampleLib {
    address deployer;
    address pusher;
    address filler;

    function setUp() external {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        vm.deal(deployer, 1 ether);
        vm.deal(pusher, 1 ether);
        vm.deal(filler, 1 ether);

        // Label operations in the run function.
        vm.label(deployer, "deployer");
        vm.label(pusher, "pusher");
        vm.label(filler, "filler");
    }

    function testFail_run1() external {
        // start deployer land
        vm.startPrank(deployer);
        deployerLand(pusher, filler);
        vm.stopPrank();

        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumber, filler, 20);
        vm.stopPrank();

        assertEq(erc20a.balanceOf(pusherLaminated), 0);
        assertEq(erc20b.balanceOf(pusherLaminated), 20);
        assertEq(erc20a.balanceOf(filler), 10);
        assertEq(erc20b.balanceOf(filler), 0);
        assertFalse(callbreaker.isPortalOpen());

        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assertFalse(init);
    }
}
