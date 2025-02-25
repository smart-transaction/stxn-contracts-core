// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/timetravel/CallBreaker.sol";
import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import {AshMintScheduler} from "src/schedulers/AshMintScheduler.sol";
import {AshToken} from "src/tokens/AshToken.sol";
import {DATATYPE} from "src/TimeTypes.sol";
import {IMintableERC20} from "test/utils/interfaces/IMintableERC20.sol";

contract AshMintSchedulerLib {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct AshMintData {
        uint256 ashBIAmount;
        uint256 ashBAmount;
        uint256 ashBISAmount;
        uint256 blockNumber;
    }

    address payable public pusherLaminated;
    AshToken public ashBI;
    AshToken public ashB;
    AshToken public ashBIS;
    AshMintScheduler public ashMintScheduler;

    Laminator public laminator;
    CallBreaker public callBreaker;

    uint256 constant tipWei = 33;
    bytes32 public constant SELECTOR = keccak256(abi.encode("ASHMINT"));

    function deployerLand(address pusher, address deployer) public {
        // Initializing contracts
        callBreaker = new CallBreaker();
        laminator = new Laminator(address(callBreaker));

        ashBI = new AshToken(deployer);
        ashB = new AshToken(deployer);
        ashBIS = new AshToken(deployer);

        ashMintScheduler = new AshMintScheduler(
            address(callBreaker), address(callBreaker), address(ashBI), address(ashB), address(ashBIS), deployer
        );
        ashBI.grantRole(MINTER_ROLE, address(ashMintScheduler));
        ashB.grantRole(MINTER_ROLE, address(ashMintScheduler));
        ashBIS.grantRole(MINTER_ROLE, address(ashMintScheduler));

        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        ashMintScheduler.grantRole(ashMintScheduler.ASH_MINTER(), pusherLaminated);
    }

    function userLand() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](3);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(ashMintScheduler),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("mintAsh()")
        });

        CallObject memory callObjectContinueFunctionPointer = CallObject({
            amount: 0,
            addr: address(ashMintScheduler),
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

        SolverData memory data = SolverData({name: "ASHMINT", datatype: DATATYPE.STRING, value: "xx"});
        SolverData[] memory dataValues = new SolverData[](1);
        dataValues[0] = data;

        return laminator.pushToProxy(pusherCallObjs, 1, SELECTOR, dataValues);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler) public {
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

        AdditionalData[] memory associatedData = new AdditionalData[](3);
        associatedData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("tipYourBartender")), value: abi.encodePacked(filler)});
        associatedData[1] =
            AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(laminatorSequenceNumber)});
        associatedData[2] = AdditionalData({
            key: keccak256(abi.encodePacked("AshMintData")),
            value: abi.encode(AshMintData({ashBIAmount: 10, ashBAmount: 11, ashBISAmount: 12, blockNumber: 2}))
        });

        callBreaker.executeAndVerify(callObjs, returnObjs, associatedData);
    }
}
