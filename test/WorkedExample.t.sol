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
        emit log_uint(0);
        // start deployer land
        vm.startPrank(deployer);
        emit log_uint(1);
        deployerLand(pusher, filler);
        emit log_uint(2);
        vm.stopPrank();
        emit log_uint(3);

        uint256 laminatorSequenceNumber;

        emit log_uint(4);
        vm.startPrank(pusher);
        emit log_uint(5);
        laminatorSequenceNumber = userLand();
        emit log_uint(6);
        vm.stopPrank();

        emit log_uint(7);
        // go forward in time
        vm.roll(block.number + 1);
        emit log_uint(8);

        vm.startPrank(filler);
        emit log_uint(9);
        solverLand(laminatorSequenceNumber, filler, 20);
        emit log_uint(100);
        vm.stopPrank();
        emit log_uint(101);

        emit log_uint(102);
        assertEq(erc20a.balanceOf(pusherLaminated), 0);
        emit log_uint(103);
        assertEq(erc20b.balanceOf(pusherLaminated), 20);
        emit log_uint(104);
        assertEq(erc20a.balanceOf(filler), 10);
        emit log_uint(105);
        assertEq(erc20b.balanceOf(filler), 0);
        emit log_uint(106);
        assertFalse(callbreaker.isPortalOpen());
        emit log_uint(107);

        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        emit log_uint(108);
        assertFalse(init);
        emit log_uint(109);
    }
}
