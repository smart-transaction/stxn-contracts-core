// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {CallBreaker, CallObject, ReturnObject, AdditionalData} from "src/timetravel/CallBreaker.sol";
import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import {KITNDisbursalContract} from "src/utilities/KITNDisbursalContract.sol";
import {KITNDisburmentScheduler} from "test/examples/MEVOracle/KITNDisburmentScheduler.sol";
import {MockERC20Token} from "test/utils/MockERC20Token.sol";
import {Constants} from "test/utils/Constants.sol";
import {DATATYPE} from "src/TimeTypes.sol";

contract KITNDisburmentSchedulerLib {
    bytes32 public constant SELECTOR = keccak256(abi.encode("KITN.DISBURSAL"));
    address public constant owner = 0x335858f4c351DE51AcD8BeDE5c8889D2390083f7;

    address payable public pusherLaminated;
    MockERC20Token public kitn;
    KITNDisburmentScheduler public kitnDisbursalSchedular;
    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 _tipWei = 33;

    function deployerLand(address pusher, address deployer) public {
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        kitn = new MockERC20Token("KITN", "KITN");

        // deploy schedular and grant role to intiate disbursal
        KITNDisbursalContract kdc = new KITNDisbursalContract(address(kitn), deployer);
        kitnDisbursalSchedular = new KITNDisburmentScheduler(address(callbreaker), address(kdc), owner);
        kdc.grantRole(kdc.DISBURSER(), address(kitnDisbursalSchedular));

        // mint and approve disbursor contract to transfer tokens
        kitn.mint(deployer, 1000000e18);
        kitn.approve(address(kdc), type(uint256).max);
    }

    function userLand() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](3);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(kitnDisbursalSchedular),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("disburseKITNs()")
        });

        CallObject memory callObjectContinueFunctionPointer = CallObject({
            amount: 0,
            addr: address(kitnDisbursalSchedular),
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

        pusherCallObjs[2] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});

        SolverData memory data = SolverData({name: "CRON", datatype: DATATYPE.UINT256, value: "5m"});
        SolverData[] memory dataValues = new SolverData[](1);
        dataValues[0] = data;

        return laminator.pushToProxy(pusherCallObjs, 1, SELECTOR, dataValues);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler) public {
        KITNDisburmentScheduler.DisbursalData memory data = _getDisbursalData(filler);

        CallObject[] memory callObjs = new CallObject[](2);
        ReturnObject[] memory returnObjs = new ReturnObject[](2);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        callObjs[1] = CallObject({
            amount: 0,
            addr: address(kitnDisbursalSchedular),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("verifySignature(bytes)", abi.encode(data))
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](3);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: abi.encode(laminatorSequenceNumber + 1)});
        returnObjsFromPull[2] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[1] = ReturnObject({returnvalue: ""});

        // mock value for signature
        bytes memory signature = abi.encode("signature");

        AdditionalData[] memory associatedData = new AdditionalData[](4);
        associatedData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("tipYourBartender")), value: abi.encodePacked(filler)});
        associatedData[1] =
            AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(laminatorSequenceNumber)});
        associatedData[2] =
            AdditionalData({key: keccak256(abi.encodePacked("KITNDisbursalData")), value: abi.encode(data)});
        associatedData[3] = AdditionalData({key: keccak256(abi.encodePacked("CleanAppSignature")), value: signature});

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        callbreaker.executeAndVerify(
            callObjs, returnObjs, associatedData
        );
    }

    function _getDisbursalData(address receiver) private pure returns (KITNDisburmentScheduler.DisbursalData memory) {
        address[] memory receivers = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        receivers[0] = receiver;
        amounts[0] = 1e18;

        return KITNDisburmentScheduler.DisbursalData({receivers: receivers, amounts: amounts});
    }
}
