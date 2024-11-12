// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "test/examples/DeFi/MockDaiWethPool.sol";
import "test/examples/DeFi/MockLiquidityProvider.sol";
import "test/utils/MockERC20Token.sol";
import "test/utils/Constants.sol";

contract FlashLiquidityLib {
    address payable public pusherLaminated;
    MockERC20Token public dai;
    MockERC20Token public weth;
    MockDaiWethPool public daiWethPool;
    MockLiquidityProvider public liquidityProvider;

    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 _tipWei = 33;

    function deployerLand(address pusher) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        dai = new MockERC20Token("Dai", "DAI");
        weth = new MockERC20Token("Weth", "WETH");
        daiWethPool = new MockDaiWethPool(address(callbreaker), address(dai), address(weth));
        daiWethPool.mintInitialLiquidity();

        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        dai.mint(pusherLaminated, 10000 * 1e18);

        liquidityProvider = new MockLiquidityProvider(dai, weth);
        dai.mint(address(liquidityProvider), 1000000000 * 1e18);
        weth.mint(address(liquidityProvider), 10000 * 1e18);
    }

    function userLand(uint256 tokenToApprove, uint256 amountIn, uint256 slippagePercent) public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        // Temporarily, this example uses a call to swap but only sets slippage protection in
        // sqrtPriceLimitX96 (not within the call to Uniswaps)
        // TODO: On swap, needs to also enforce invariant: funds must get returned to the user.
        CallObject[] memory pusherCallObjs = new CallObject[](3);
        pusherCallObjs[0] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});
        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(dai),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", daiWethPool, tokenToApprove)
        });
        pusherCallObjs[2] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("swapDAIForWETH(uint256,uint256)", amountIn, slippagePercent)
        });

        SolverData[] memory dataValues = Constants.emptyDataValues();

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1, "0x00", dataValues);
    }

    function solverLand(
        uint256 liquidity0,
        uint256 liquidity1,
        uint256 laminatorSequenceNumber,
        uint256 maxDeviationPercentage,
        address filler
    ) public {
        CallObject[] memory callObjs = new CallObject[](5);
        ReturnObject[] memory returnObjs = new ReturnObject[](5);

        callObjs[0] = CallObject({
            amount: 0,
            addr: address(liquidityProvider),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "approveTransfer(address,uint256,uint256)", address(daiWethPool), liquidity0, liquidity1
            )
        });

        callObjs[1] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "provideLiquidityToDAIETHPool(address,uint256,uint256)", liquidityProvider, liquidity0, liquidity1
            )
        });

        callObjs[2] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        callObjs[3] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", maxDeviationPercentage)
        });

        callObjs[4] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "withdrawLiquidityFromDAIETHPool(address,uint256,uint256)", liquidityProvider, liquidity0, liquidity1
            )
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](3);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[2] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjs[1] = ReturnObject({returnvalue: ""});
        returnObjs[2] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[3] = ReturnObject({returnvalue: ""});
        returnObjs[4] = ReturnObject({returnvalue: ""});

        AdditionalData[] memory associatedData = new AdditionalData[](2);
        associatedData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("tipYourBartender")), value: abi.encodePacked(filler)});
        associatedData[1] =
            AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(laminatorSequenceNumber)});

        AdditionalData[] memory hintdices = new AdditionalData[](5);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});
        hintdices[2] = AdditionalData({key: keccak256(abi.encode(callObjs[2])), value: abi.encode(2)});
        hintdices[3] = AdditionalData({key: keccak256(abi.encode(callObjs[3])), value: abi.encode(3)});
        hintdices[4] = AdditionalData({key: keccak256(abi.encode(callObjs[4])), value: abi.encode(4)});

        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
    }
}
