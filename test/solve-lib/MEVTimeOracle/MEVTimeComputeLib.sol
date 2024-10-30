// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "test/examples/MEVOracle/MEVTimeCompute.sol";
import "test/utils/Constants.sol";

contract MEVTimeComputeLib {
    address payable public pusherLaminated;
    MEVTimeCompute public mevTimeCompute;
    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 _tipWei = 33;

    function deployerLand(address pusher, uint256 divisor, uint256 initValue) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        mevTimeCompute = new MEVTimeCompute(address(callbreaker), divisor);
        mevTimeCompute.setInitValue(initValue);
    }

    function userLand() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(mevTimeCompute),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("solve()")
        });

        pusherCallObjs[1] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});

        SolverData[] memory dataValues = Constants.emptyDataValues();

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1, "0x00", dataValues);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler) public {
        uint256 value = mevTimeCompute.initValue();
        uint256 divisor = mevTimeCompute.divisor();
        uint256 solution = divisor - (value % divisor);
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
            addr: address(mevTimeCompute),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("verifySolution()")
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        returnObjs[1] = ReturnObject({returnvalue: ""});

        AdditionalData[] memory associatedData = new AdditionalData[](3);
        associatedData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("tipYourBartender")), value: abi.encodePacked(filler)});
        associatedData[1] =
            AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(laminatorSequenceNumber)});
        associatedData[2] =
            AdditionalData({key: keccak256(abi.encodePacked("solvedValue")), value: abi.encode(solution)});

        AdditionalData[] memory hintdices = new AdditionalData[](2);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});
        hintdices[1] = AdditionalData({key: keccak256(abi.encode(callObjs[1])), value: abi.encode(1)});

        callbreaker.executeAndVerify(
            abi.encode(callObjs), abi.encode(returnObjs), abi.encode(associatedData), abi.encode(hintdices)
        );
    }
}
