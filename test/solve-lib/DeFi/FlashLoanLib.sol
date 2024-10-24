// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "test/examples/DeFi/MockDaiWethPool.sol";
import "test/examples/DeFi/MockFlashLoan.sol";
import "test/utils/MockERC20Token.sol";
import "test/utils/Constants.sol";
import {FlashLoanData} from "src/CallBreakerTypes.sol";

contract FlashLoanLib {
    address payable public pusherLaminated;
    MockERC20Token public dai;
    MockERC20Token public weth;
    MockDaiWethPool public daiWethPool;
    MockFlashLoan public flashLoan;

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
        dai.mint(pusherLaminated, 100000000000000000000);

        flashLoan = new MockFlashLoan(address(dai), address(weth));
        dai.mint(address(flashLoan), 1009000000000000000000);
        weth.mint(address(flashLoan), 1000000000000000000000);
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

        ILaminator.AdditionalData[] memory dataValues = Constants.emptyDataValues();

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1, "0x00", dataValues);
    }

    function solverLand(
        uint256 liquidity0,
        uint256 liquidity1,
        uint256 laminatorSequenceNumber,
        uint256 maxDeviationPercentage,
        address filler
    ) public {
        CallObject[] memory callObjs = new CallObject[](6);
        ReturnObject[] memory returnObjs = new ReturnObject[](6);

        callObjs[0] = CallObject({
            amount: 0,
            addr: address(dai),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(daiWethPool), liquidity0 * 1e18)
        });

        callObjs[1] = CallObject({
            amount: 0,
            addr: address(weth),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(daiWethPool), liquidity1 * 1e18)
        });

        callObjs[2] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "provideLiquidityToDAIETHPool(address,uint256,uint256)", address(callbreaker), liquidity0, liquidity1
            )
        });

        callObjs[3] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        callObjs[4] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", maxDeviationPercentage)
        });

        callObjs[5] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "withdrawLiquidityFromDAIETHPool(address,uint256,uint256)", address(callbreaker), liquidity0, liquidity1
            )
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](3);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[2] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjs[2] = ReturnObject({returnvalue: ""});
        returnObjs[3] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[4] = ReturnObject({returnvalue: ""});
        returnObjs[5] = ReturnObject({returnvalue: ""});

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encodePacked(filler);
        values[1] = abi.encode(laminatorSequenceNumber);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](5);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        hintdicesKeys[2] = keccak256(abi.encode(callObjs[2]));
        hintdicesKeys[3] = keccak256(abi.encode(callObjs[3]));
        hintdicesKeys[4] = keccak256(abi.encode(callObjs[4]));
        uint256[] memory hintindicesVals = new uint256[](5);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        hintindicesVals[2] = 2;
        hintindicesVals[3] = 3;
        hintindicesVals[4] = 4;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);

        callbreaker.executeAndVerify(
            abi.encode(callObjs),
            abi.encode(returnObjs),
            encodedData,
            hintdices,
            abi.encode(generateFlashLoanData(address(flashLoan)))
        );
    }

    function generateFlashLoanData(address _flashLoan) public pure returns (FlashLoanData memory) {
        FlashLoanData memory flashLoanData =
            FlashLoanData({provider: _flashLoan, amountA: 1000 * 1e18, amountB: 100 * 1e18});
        return flashLoanData;
    }
}
