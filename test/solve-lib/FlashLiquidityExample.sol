// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";
import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../test/examples/LimitOrder.sol";
import "../../src/timetravel/SmarterContract.sol";
import "../utils/MockERC20Token.sol";
import "../utils/MockSwapRouter.sol";
import "../utils/MockPositionManager.sol";

contract FlashLiquidityExampleLib {
    address payable public pusherLaminated;
    MockERC20Token public aToken;
    MockERC20Token public bToken;
    MockSwapRouter public swapRouter;
    MockPositionManager public positionManager;
    LimitOrder public limitOrder;
    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 _tipWei = 33;

    function deployerLand(address pusher) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        aToken = new MockERC20Token("AToken", "AT");
        bToken = new MockERC20Token("BToken", "BT");
        swapRouter = new MockSwapRouter(address(aToken), address(bToken));
        positionManager = new MockPositionManager(address(swapRouter));
        limitOrder = new LimitOrder(
            address(swapRouter), address(callbreaker), address(positionManager), address(aToken), address(bToken)
        );
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        aToken.mint(100000000000000000000, pusherLaminated);
        aToken.mint(100000000000000000000, address(callbreaker));
    }

    function userLand(uint256 tokenToApprove, uint256 amountIn, uint256 slippagePercent) public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        // Temporarily, this example uses a call to swap but only sets slippage protection in
        // sqrtPriceLimitX96 (not within the call to Uniswaps)
        // TODO: On swap, needs to also enforce invariant: funds must get returned to the user.
        CallObject[] memory pusherCallObjs = new CallObject[](4);
        pusherCallObjs[0] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});
        pusherCallObjs[1] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});
        pusherCallObjs[2] = CallObject({
            amount: 0,
            addr: address(aToken),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", limitOrder, tokenToApprove)
        });
        pusherCallObjs[3] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("swapDAIForWETH(uint256,uint256)", amountIn, slippagePercent)
        });

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLand(
        uint256 liquidity,
        uint256 laminatorSequenceNumber,
        uint256 maxDeviationPercentage,
        address filler
    ) public {
        CallObject[] memory callObjs = new CallObject[](4);
        ReturnObject[] memory returnObjs = new ReturnObject[](4);

        callObjs[0] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("provideLiquidityToDAIETHPool(uint256,uint256)", liquidity, liquidity)
        });

        callObjs[1] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        callObjs[2] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", maxDeviationPercentage)
        });

        callObjs[3] = CallObject({
            amount: 0,
            addr: address(limitOrder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("withdrawLiquidityFromDAIETHPool()")
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](4);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[2] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[3] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: ""});
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[2] = ReturnObject({returnvalue: ""});
        returnObjs[3] = ReturnObject({returnvalue: ""});

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encodePacked(filler);
        values[1] = abi.encode(laminatorSequenceNumber);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](4);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        hintdicesKeys[2] = keccak256(abi.encode(callObjs[2]));
        hintdicesKeys[3] = keccak256(abi.encode(callObjs[3]));
        uint256[] memory hintindicesVals = new uint256[](4);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        hintindicesVals[2] = 2;
        hintindicesVals[3] = 3;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }
}
