// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/timetravel/CallBreaker.sol";
import "../src/examples/TemporalStates.sol";

// Use the callbreaker to verify a temporal state
// The user should push a call to the laminated mempool that has a temporal state
// At different blocktimes, the callbreaker should return different values
// The callbreaker should return the correct value at the correct time using a partial function
// Takes a value at MEV time similar to the flow in setSwapPartner, but with arbitrary bytes
// Whatever gets pulled in the example will take from contract, decode and use the thing
contract TemporalTest is Test {
    CallBreaker public callbreaker;
    TemporalStates public temporalstates;

    function setUp() public {
        callbreaker = new CallBreaker();
        temporalstates = new TemporalStates(address(callbreaker));
    }

    function testVulnerable() public {
        (bool success, bytes memory ret) =
            address(temporalstates).call{gas: 1000000, value: 0}(abi.encodeWithSignature("entryPoint(uint256,bytes)", uint256(3), 'vulnerable'));

        require(success, "call failed");
        assertEq(abi.decode(ret, (bool)), true, "call returned wrong value");
    }

    function testTemporal() public {
        // Move forward in time
        vm.roll(3);
        console.logUint(block.number);
        // build the call stack
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(temporalstates),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("timeExploit(uint256,bytes)", block.number, 'vulnerable')
        });

        ReturnObject[] memory returnObjs = new ReturnObject[](1);
        returnObjs[0] = ReturnObject({returnvalue: abi.encode(true)});

        bytes memory callObjsBytes = abi.encode(callObjs);
        bytes memory returnObjsBytes = abi.encode(returnObjs);

        // call verify
        callbreaker.verify(callObjsBytes, returnObjsBytes);
    }
    
    function testfuzzTemporal(bytes memory vulnerable) public {
        // Move forward in time
        vm.roll(3);
        console.logUint(block.number);
        // build the call stack
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(temporalstates),
            gas: 1000000,
            callvalue: abi.encodeWithSignature('timeExploit(uint256,bytes)', block.number, vulnerable)
        });

        ReturnObject[] memory returnObjs = new ReturnObject[](1);
        returnObjs[0] = ReturnObject({returnvalue: abi.encode(true)});

        bytes memory callObjsBytes = abi.encode(callObjs);
        bytes memory returnObjsBytes = abi.encode(returnObjs);

        // call verify
        callbreaker.verify(callObjsBytes, returnObjsBytes);
    }
}