// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/LimitOrder.sol";
import "../test/solve-lib/FlashLiquidityExample.sol";

contract FlashLiquidityTest is Test, FlashLiquidityExampleLib {
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

        vm.startPrank(pusher);
        laminatorSequenceNumber = userLand();
        vm.stopPrank();

        // go forward in time
        vm.roll(block.number + 1);

        vm.startPrank(filler);
        solverLand(laminatorSequenceNumber, filler);
        vm.stopPrank();

        assertFalse(callbreaker.isPortalOpen());

        (bool init, bool exec,) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);

        assertTrue(init);
        assertTrue(exec);
    }

    function testFlashLiquiditySlippage() public {
        CallObject[] memory callObjs = new CallObject[](3);
        ReturnObject[] memory returnObjs = new ReturnObject[](3);

        callObjs[0] = CallObject({
            amount: 0,
            addr: address(aToken),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", limitOrder, 100000000000000000000)
        });
        callObjs[1] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("swapDAIForWETH(uint256,uint256)", 10, 1) // calls checkSlippage and fail with invalid price limit
        });

        callObjs[2] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", 1)
        });

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjs[1] = ReturnObject({returnvalue: ""});
        returnObjs[2] = ReturnObject({returnvalue: ""});

        bytes32[] memory keys = new bytes32[](0);
        bytes[] memory values = new bytes[](0);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        vm.startPrank(filler);
        vm.expectRevert();
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }
}
