// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";
import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../test/examples/LimitOrder.sol";
import "../../src/timetravel/SmarterContract.sol";

contract FlashLiquidityExampleLib {
    address payable public pusherLaminated;
    LimitOrder public limitOrder;
    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 _tipWei = 33;

    function deployerLand(address pusher) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        limitOrder = new LimitOrder(address(callbreaker));
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
    }

    function userLand() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        // Temporarily, this example uses a call to swap but only sets slippage protection in
        // sqrtPriceLimitX96 (not within the call to Uniswaps)
        // TODO: On swap, needs to also enforce invariant: funds must get returned to the user.
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("swapDAIForWETH(uint256,uint160)", 100, 200)
        });

        pusherCallObjs[1] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler) public {
        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        //TODO: Solver should provide liquidity here before the call to checkSlippage
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("provideLiquidityToDAIETHPool(uint256)", laminatorSequenceNumber)
        });

        callObjs[1] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        callObjs[1] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", laminatorSequenceNumber)
        });

        returnObjs[1] = ReturnObject({returnvalue: ""});

        bytes32[] memory keys = new bytes32[](3);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        keys[2] = keccak256(abi.encodePacked("hintdex"));
        bytes[] memory values = new bytes[](3);
        values[0] = abi.encodePacked(filler);
        values[1] = abi.encode(laminatorSequenceNumber);
        values[2] = abi.encode(2);
        bytes memory encodedData = abi.encode(keys, values);

        // In this specific test, we don't have to use hintdices because the call list is short.
        // Hintdices will be used in longer call sequences.
        bytes32[] memory hintdicesKeys = new bytes32[](2);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        uint256[] memory hintindicesVals = new uint256[](2);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }
}
