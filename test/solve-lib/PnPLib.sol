// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Vm.sol";

import {Laminator, SolverData} from "src/lamination/Laminator.sol";
import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "test/examples/PnP.sol";
import "test/utils/Constants.sol";

contract PnPLib {
    address payable public pusherLaminated;
    PnP public pnp;
    Laminator public laminator;
    CallBreaker public callbreaker;
    uint256 _tipWei = 33;
    uint256 hashChainInitConst = 1;

    function deployerLand(address pusher) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));
        pnp = new PnP(address(callbreaker), hashChainInitConst);
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
    }

    function userLand() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // 5th member of the hash-chain
        address fifthInList = PnP(address(pnp)).hash(
            PnP(address(pnp)).hash(
                PnP(address(pnp)).hash(PnP(address(pnp)).hash(PnP(address(pnp)).hash(hashChainInitConst)))
            )
        );

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(pnp),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("callBreakerNp(address)", fifthInList)
        });

        pusherCallObjs[1] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});
        SolverData[] memory dataValues = Constants.emptyDataValues();

        return laminator.pushToProxy(pusherCallObjs, 1, "0x00", dataValues);
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

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: abi.encode(4)});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        AdditionalData[] memory associatedData = new AdditionalData[](3);
        associatedData[0] =
            AdditionalData({key: keccak256(abi.encodePacked("tipYourBartender")), value: abi.encodePacked(filler)});
        associatedData[1] =
            AdditionalData({key: keccak256(abi.encodePacked("pullIndex")), value: abi.encode(laminatorSequenceNumber)});
        associatedData[2] = AdditionalData({key: keccak256(abi.encodePacked("hintdex")), value: abi.encode(4)});

        AdditionalData[] memory hintdices = new AdditionalData[](1);
        hintdices[0] = AdditionalData({key: keccak256(abi.encode(callObjs[0])), value: abi.encode(0)});

        callbreaker.executeAndVerify(
            callObjs, returnObjs, associatedData
        );
    }
}
