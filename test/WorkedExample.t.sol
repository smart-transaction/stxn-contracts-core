// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "./solve-lib/WorkedExample.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/SelfCheckout.sol";
import "../test/examples/MyErc20.sol";

contract WorkedExampleTest is Script, WorkedExampleLib {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
    uint256 pusherPrivateKey = vm.envUint("PRIVATE_KEY2");
    uint256 fillerPrivateKey = vm.envUint("PRIVATE_KEY3");

    address pusher = vm.addr(pusherPrivateKey);
    address filler = vm.addr(fillerPrivateKey);
    address deployer = vm.addr(deployerPrivateKey);

    function setUp() external {
        // start deployer land
        vm.prank(deployer);
        deployerLand(pusher, filler);

        // Label operations in the run function.
        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");
    }

    function test_run() external {
        uint256 laminatorSequenceNumber;

        vm.prank(pusher);
        laminatorSequenceNumber = userLand();

        // go forward in time
        vm.roll(block.number + 1);

        vm.prank(filler);
        solverLand(laminatorSequenceNumber, filler, 20);

        assert(erc20a.balanceOf(pusherLaminated) == 0);
        assert(erc20b.balanceOf(pusherLaminated) == 20);
        assert(erc20a.balanceOf(filler) == 10);
        assert(erc20b.balanceOf(filler) == 0);
        assert(!callbreaker.isPortalOpen());

        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assert(!init);
    }
}
