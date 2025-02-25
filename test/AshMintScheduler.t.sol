// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "test/solve-lib/Ash/AshMintSchedulerLib.sol";

contract AshMintSchedulerTest is Test, AshMintSchedulerLib {
    address public deployer;
    address public pusher;
    address public filler;

    function setUp() external {
        deployer = address(100);
        pusher = address(200);
        filler = address(300);

        // give the pusher some eth
        vm.deal(pusher, 100 ether);

        // start deployer calls
        vm.startPrank(deployer);
        deployerLand(pusher, deployer);
        vm.stopPrank();

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function testMintSchedule() external {
        uint256 laminatorSequenceNumber;

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand();
        vm.stopPrank();

        uint256 initialFillerBalance = address(filler).balance;

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler, filler);

        solverLand(laminatorSequenceNumber, filler);

        vm.stopPrank();

        vm.roll(block.number + 8000);

        vm.startPrank(filler, filler);
        solverLand(laminatorSequenceNumber + 1, filler);
        vm.stopPrank();

        assertEq(address(filler).balance, initialFillerBalance + 2 * 33);
    }
}
