// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/timetravel/CallBreaker.sol";
import {IBlockTime, BlockTime} from "src/utilities/BlockTime.sol";
import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import {BlockTimeScheduler} from "src/schedulers/BlockTimeScheduler.sol";
import {TimeToken} from "src/tokens/TimeToken.sol";
import {DATATYPE} from "src/TimeTypes.sol";

contract BlockTimeSchedulerLib {
    address payable public pusherLaminated;
    TimeToken public timeToken;
    Laminator public laminator;
    CallBreaker public callBreaker;
    BlockTime public blockTime;
    BlockTimeScheduler public blockTimeScheduler;

    string constant timeTokenName = "Time Token";
    string constant timeTokenSymbol = "TIME";
    uint256 constant tipWei = 33;
    bytes32 public constant SELECTOR = keccak256(abi.encode("BLOCKTIME.UPDATE_TIME"));

    function deployerLand(address pusher, address deployer) public {
        // Initializing contracts
        callBreaker = new CallBreaker();
        laminator = new Laminator(address(callBreaker));
        blockTime = new BlockTime(deployer);
        blockTimeScheduler = new BlockTimeScheduler(address(callBreaker), address(blockTime), deployer);
        blockTime.grantRole(blockTime.SCHEDULER_ROLE(), address(blockTimeScheduler));
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        blockTimeScheduler.grantRole(blockTimeScheduler.TIME_SOLVER(), address(pusherLaminated));
    }

    function userLand() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](3);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(blockTimeScheduler),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("updateTime()")
        });

        CallObject memory callObjectContinueFunctionPointer = CallObject({
            amount: 0,
            addr: address(blockTimeScheduler),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("shouldContinue()")
        });
        bytes memory callObjectContinueFnPtr = abi.encode(callObjectContinueFunctionPointer);

        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("copyCurrentJob(uint256,bytes)", 0, callObjectContinueFnPtr)
        });

        pusherCallObjs[2] = CallObject({amount: tipWei, addr: address(callBreaker), gas: 10000000, callvalue: ""});

        SolverData memory data = SolverData({name: "BLOCKCLOCK", datatype: DATATYPE.STRING, value: "xx"});
        SolverData[] memory dataValues = new SolverData[](1);
        dataValues[0] = data;

        return laminator.pushToProxy(pusherCallObjs, 1, SELECTOR, dataValues);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler, address pusher) public {
        (bytes memory chroniclesData, bytes memory meanTimeData, bytes memory receiversData, bytes memory amountsData) =
            _getUpdateTimeData(filler, pusher);

        CallObject[] memory callObjs = new CallObject[](1);
        ReturnObject[] memory returnObjs = new ReturnObject[](1);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](3);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: abi.encode(laminatorSequenceNumber + 1)});
        returnObjsFromPull[2] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        AdditionalData[] memory associatedData = new AdditionalData[](6);
        associatedData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("tipYourBartender")), value: abi.encodePacked(filler)});
        associatedData[1] =
            AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(laminatorSequenceNumber)});
        associatedData[2] = AdditionalData({key: keccak256(abi.encodePacked("Chronicles")), value: chroniclesData});
        associatedData[3] = AdditionalData({key: keccak256(abi.encodePacked("CurrentMeanTime")), value: meanTimeData});
        associatedData[4] = AdditionalData({key: keccak256(abi.encodePacked("Recievers")), value: receiversData});
        associatedData[5] = AdditionalData({key: keccak256(abi.encodePacked("Amounts")), value: amountsData});

        callBreaker.executeAndVerify(callObjs, returnObjs, associatedData);
    }

    function _getUpdateTimeData(address receiver, address pusher)
        private
        view
        returns (
            bytes memory chroniclesData,
            bytes memory meanTimeData,
            bytes memory receiversData,
            bytes memory amountsData
        )
    {
        IBlockTime.Chronicle[] memory chronicles = new IBlockTime.Chronicle[](1);
        chronicles[0] = IBlockTime.Chronicle(100, pusher, bytes(""));
        address[] memory receivers = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        receivers[0] = receiver;
        amounts[0] = 1e18;

        chroniclesData = abi.encode(chronicles);
        meanTimeData = abi.encode(block.timestamp);
        receiversData = abi.encode(receivers);
        amountsData = abi.encode(amounts);
    }
}
