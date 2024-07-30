// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "test/examples/DeFi/SwapPool.sol";
import "test/utils/MockERC20Token.sol";
import "test/utils/MockSwapRouter.sol";
import "test/utils/MockPositionManager.sol";

contract SlippageProtectionLib {
    address payable public pusherLaminated;
    MockERC20Token public aToken;
    MockERC20Token public bToken;
    MockSwapRouter public swapRouter;
    MockPositionManager public positionManager;
    SwapPool public pool;
    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 private _tipWei = 33;

    function deployerLand(address pusher) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        aToken = new MockERC20Token("AToken", "AT");
        bToken = new MockERC20Token("BToken", "BT");
        swapRouter = new MockSwapRouter(address(aToken), address(bToken));
        positionManager = new MockPositionManager(address(swapRouter));
        pool = new SwapPool(
            address(swapRouter), address(callbreaker), address(positionManager), address(aToken), address(bToken)
        );
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        aToken.mint(100e18, pusherLaminated);
        bToken.mint(100e18, address(callbreaker));
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
            addr: address(aToken),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", pool, 100e18)
        });
        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(pool),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("swapDAIForWETH(uint256,uint256)", 100, maxSlippage)
        });
        pusherCallObjs[2] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
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
            addr: address(swapRouter),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("checkSlippage(uint256)", maxSlippage)
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
