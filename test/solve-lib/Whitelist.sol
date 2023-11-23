// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../test/examples/Caller.sol";
import "../../src/timetravel/SmarterContract.sol";
import "../../test/examples/NoopTurner.sol";

contract Whitelist {
    address payable public pusherLaminated;
    NoopTurner public noopturner_ofacBlocked;
    NoopTurner public noopturner_audited;
    Laminator public laminator;
    Caller public caller;
    CallBreaker public callbreaker;
    uint256 _tipWei = 33;

    function deployerLand(address pusher) public {
        // Initializing contracts
        laminator = new Laminator();
        callbreaker = new CallBreaker();
        noopturner_ofacBlocked = new NoopTurner(address(callbreaker));
        noopturner_audited = new NoopTurner(address(callbreaker));
        caller = new Caller(address(callbreaker), address(noopturner_ofacBlocked), address(noopturner_audited));
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
    }

    function userLandWhitelist() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(caller),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "callWhitelisted(address,bytes)",
                address(noopturner_audited),
                abi.encodeWithSignature("vanilla(uint16)", uint16(42))
                ),
            delegate: false
        });

        pusherCallObjs[1] =
            CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: "", delegate: false});

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLandWhitelist(uint256 laminatorSequenceNumber, address filler) public {
        CallObject[] memory callObjs = new CallObject[](1);
        ReturnObject[] memory returnObjs = new ReturnObject[](1);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber),
            delegate: false
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encode(filler);
        values[1] = abi.encode(laminatorSequenceNumber);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](1);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        uint256[] memory hintindicesVals = new uint256[](1);
        hintindicesVals[0] = 0;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    function userLandBlackList() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(caller),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "callAnyButBlacklisted(address,bytes)",
                address(noopturner_ofacBlocked),
                abi.encodeWithSignature("vanilla(uint16)", uint16(42))
                ),
            delegate: false
        });

        pusherCallObjs[1] =
            CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: "", delegate: false});

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLandBlackList(uint256 laminatorSequenceNumber, address filler) public {
        CallObject[] memory callObjs = new CallObject[](1);
        ReturnObject[] memory returnObjs = new ReturnObject[](1);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber),
            delegate: false
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encode(filler);
        values[1] = abi.encode(laminatorSequenceNumber);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](1);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        uint256[] memory hintindicesVals = new uint256[](1);
        hintindicesVals[0] = 0;
        bytes memory hintdices = abi.encode(hintdicesKeys, hintindicesVals);
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintdices);
    }

    //@TODO: add unaudited and normal cases
}
