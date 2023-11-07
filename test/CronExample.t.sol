// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./solve-lib/CronExample.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/SelfCheckout.sol";
import "../test/examples/MyErc20.sol";

contract CronExampleTest is Test, CronExampleLib {
    address deployer;
    address pusher;
    address filler;

    function setUp() external {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        // start deployer land
        vm.startPrank(deployer);
        deployerLand(pusher);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    /* To execute `test_cron_run()` with Kontrol:
        kontrol build --rekompile --require lemmas.k --module-import CronExampleTest:STXN-LEMMAS
        kontrol prove --match-test CronExampleTest.test_cron_run --use-booster --max-depth 3000 --no-break-on-calls --auto-abstract-gas --reinit
    */
    function test_cron_run() external {
        vm.roll(1234);
        vm.coinbase(address(400));

        uint256 laminatorSequenceNumberFirst;
        uint256 laminatorSequenceNumberSecond;

        vm.startPrank(pusher);
        (laminatorSequenceNumberFirst, laminatorSequenceNumberSecond) = userLand();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 3);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumberFirst, filler);
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 7);

        // Sequence number
        vm.startPrank(filler);
        solverLand(laminatorSequenceNumberSecond, filler);
        vm.stopPrank();

        assertEq(erc20a.balanceOf(filler), 10);
        assertEq(!callbreaker.isPortalOpen(), true);

        // Both of the following should be false since we already solved and cleared the tx!
        (bool init, CallObject[] memory co) =
            LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumberFirst);
        assertEq(init, false);

        (bool initSecond, CallObject[] memory coSecond) =
            LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumberSecond);
        assertEq(initSecond, false);
    }
}
