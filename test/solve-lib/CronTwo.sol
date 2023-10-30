// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../test/examples/CronTwoCounter.sol";
import "../../test/examples/CronTwoLogic.sol";

// for the next year, every day:
// tip the pusher with a little eth
// increment your pusherlaminated contract's crontwocounter :)

// the way we do this is we push a new call at the end of execution

contract CronTwoLib {
    CallBreaker public callbreaker;
    address payable public pusherLaminated;
    Laminator public laminator;
    CronTwoCounter public counter;
    CronTwoLogic public cronTwoLogic;

    function deployerLand(address pusher) public {
        // Initializing contracts
        laminator = new Laminator();
        callbreaker = new CallBreaker();

        counter = new CronTwoCounter();
        uint32 blocksInADay = 7150;
        uint256 tipWei = 100000000000000000;
        cronTwoLogic = new CronTwoLogic(address(callbreaker), address(pusherLaminated), tipWei, blocksInADay);

        // compute the pusher laminated address
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        // give the pusher some eth
        pusherLaminated.transfer(10000000000000000000);
    }

    function userLand() public returns (uint256) {
        // Userland operations
        CallObjectWithDelegateCall[] memory pusherCallObjs = new CallObjectWithDelegateCall[](2);
        pusherCallObjs[0].callObj = CallObject({
            amount: 0,
            addr: address(counter),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("increment()")
        });
        pusherCallObjs[0].delegatecall = false;

        pusherCallObjs[1].callObj = CallObject({
            amount: 0,
            addr: address(cronTwoLogic),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("cronTrailer()")
        });
        pusherCallObjs[1].delegatecall = true;
        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler) public {
        // TODO: Refactor these parts further if necessary.
        CallObject[] memory callObjs = new CallObject[](1);
        ReturnObject[] memory returnObjs = new ReturnObject[](1);

        // pull from the laminator (that's all we need)
        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        // should return a list of the return value of approve + takesomeatokenfrompusher in a list of returnobjects, abi packed, then stuck into another returnobject.
        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        // double encoding because first here second in pull()
        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        // Constructing something that'll decode happily
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        bytes[] memory values = new bytes[](1);
        values[0] = abi.encode(filler);
        bytes memory encodedData = abi.encode(keys, values);

        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData);

        callObjs[0].callvalue = abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber + 1);
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData);
    }
}
