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

    /* To execute `test_workedExample()` with Kontrol:
        kontrol build --rekompile --require lemmas.k --module-import WorkedExampleTest:STXN-LEMMAS
        kontrol prove --match-test WorkedExampleTest.testrun1 --use-booster --max-depth 3000 --no-break-on-calls --auto-abstract-gas --reinit
    */
    function test_workedExample() external {
        uint256 laminatorSequenceNumber;

        // Concretize `block.number` to avoid branching
        vm.roll(1234);
        // Concretize `block.coinbase` to avoid branching
        vm.coinbase(address(400));

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
        // Test should fail here because we already solved and cleared the tx!
        assertFalse(init);
    }
}
