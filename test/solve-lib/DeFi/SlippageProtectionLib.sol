// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "test/examples/DeFi/MockDaiWethPool.sol";
import "test/utils/MockERC20Token.sol";
import "test/utils/Constants.sol";

contract SlippageProtectionLib {
    uint256 public constant DECIMAL = 1e18;

    address payable public pusherLaminated;
    MockERC20Token public dai;
    MockERC20Token public weth;
    MockDaiWethPool public daiWethPool;
    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 private _tipWei = 33;

    function deployerLand(address pusher) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        dai = new MockERC20Token("Dai", "DAI");
        weth = new MockERC20Token("Weth", "WETH");
        daiWethPool = new MockDaiWethPool(address(callbreaker), address(dai), address(weth));
        daiWethPool.mintInitialLiquidity();
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        dai.mint(pusherLaminated, 100e18);
        weth.mint(address(callbreaker), 100e18);
    }

    function userLand(uint256 maxSlippage) public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        // Temporarily, this example uses a call to swap but only sets slippage protection in
        // sqrtPriceLimitX96 (not within the call to Uniswaps)
        CallObject[] memory pusherCallObjs = new CallObject[](3);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(dai),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", daiWethPool, 100e18)
        });
        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("swapDAIForWETH(uint256,uint256)", 100, maxSlippage)
        });
        pusherCallObjs[2] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});
        SolverData[] memory dataValues = Constants.emptyDataValues();

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1, "0x00", dataValues);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler, uint256 maxSlippage) public {
        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](3);
        returnObjsFromPull[0] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[2] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        callObjs[1] = CallObject({
            amount: 0,
            addr: address(daiWethPool),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", maxSlippage)
        });

        returnObjs[1] = ReturnObject({returnvalue: ""});

        AdditionalData[] memory associatedData = new AdditionalData[](3);
        associatedData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("tipYourBartender")), value: abi.encodePacked(filler)});
        associatedData[1] =
            AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(laminatorSequenceNumber)});
        associatedData[2] = AdditionalData({key: keccak256(abi.encodePacked("hintdex")), value: abi.encode(2)});

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
    }
}
