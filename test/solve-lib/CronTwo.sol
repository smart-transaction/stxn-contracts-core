// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../src/timetravel/InvariantGuard.sol";
import "../../test/examples/CronTwoCounter.sol";
import "../../src/tips/Tips.sol";

// for the next year, every day:
// tip the pusher with a little eth
// increment your pusherlaminated contract's crontwocounter :)

// the way we do this is we push a new call at the end of execution

contract CronTwoLib {
    InvariantGuard public invariantGuard;
    address payable public pusherLaminated;
    Laminator public laminator;
    CronTwoCounter public counter;
    //CronTwoLogic public cronTwoLogic;
    Tips public tips;
    uint32 _blocksInADay = 7150;
    uint256 _tipWei = 33;

    function deployerLand(address pusher) public {
        // Initializing contracts
        laminator = new Laminator();
        invariantGuard = new InvariantGuard(address(laminator));

        counter = new CronTwoCounter();
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
        //cronTwoLogic = new CronTwoLogic(address(invariantGuard), address(pusherLaminated));
        tips = new Tips(address(invariantGuard));
    }

    function userLand() public returns (uint256) {
        // send proxy some eth
        pusherLaminated.transfer(1 ether);

        // Userland operations
        CallObject[] memory pusherCallObjs = new CallObject[](4);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(counter),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("increment()")
        });

        pusherCallObjs[1] = CallObject({amount: _tipWei, addr: address(tips), gas: 10000000, callvalue: ""});

        CallObject memory callObjectContinueFunctionPointer = CallObject({
            amount: 0,
            addr: address(counter),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("shouldContinue()")
        });
        bytes memory callObjectContinueFnPtr = abi.encode(callObjectContinueFunctionPointer);
        pusherCallObjs[2] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("copyCurrentJob(uint256,bytes)", _blocksInADay, callObjectContinueFnPtr)
        });
        pusherCallObjs[3] = CallObject({
            amount: 0,
            addr: address(invariantGuard),
            gas: 10000000,
            callvalue: abi.encodeWithSignature("noFrontRunInThisPull()")
        });
        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler, bool isFirstTime) public {
        // TODO: Refactor these parts further if necessary.
        CallObject[] memory callObjs = new CallObject[](1);
        ReturnObject[] memory returnObjs = new ReturnObject[](1);

        // pull from the laminator (that's all we need)
        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 10000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        // should return a list of the return value of approve + takesomeatokenfrompusher in a list of returnobjects, abi packed, then stuck into another returnobject.
        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](4);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[2] = ReturnObject({returnvalue: abi.encode(1)});
        returnObjsFromPull[3] = ReturnObject({returnvalue: ""});
        // double encoding because first here second in pull()
        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        // Constructing something that'll decode happily
        bytes32[] memory keys = new bytes32[](2);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("pullIndex"));
        bytes[] memory values = new bytes[](2);
        values[0] = abi.encode(filler);
        values[1] = abi.encode(laminatorSequenceNumber);
        bytes memory encodedData = abi.encode(keys, values);

        if (!isFirstTime) {
            callObjs[0].callvalue = abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber + 1);
            returnObjsFromPull[2] = ReturnObject({returnvalue: abi.encode(2)});
            returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
            values[1] = abi.encode(laminatorSequenceNumber + 1);
        }
        invariantGuard.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData);
    }
}
