// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";

struct CallObjectHolder {
    bool initialized;
    uint256 firstCallableBlock;
    CallObject callObj;
}

contract LaminatedProxy {
    address public owner;
    address public laminator;
    uint256 public sequenceNumber = 0;

    mapping(uint256 => CallObjectHolder) public deferredCalls;

    event CallPushed(CallObject callObj, uint256 sequenceNumber);
    event CallPulled(CallObject callObj, uint256 sequenceNumber);
    event CallExecuted(CallObject callObj);

    constructor(address _laminator, address _owner) {
        owner = _owner;
        laminator = _laminator;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Proxy: Not the owner");
        _;
    }

    // this contract can receive eth but you have to spend it with execute/push/pull
    receive() external payable {}
    // view a deferred call with a given sequence number or give a false if it's uninitialized
    function viewDeferredCall(uint256 seqNumber) public view returns (bool, CallObject memory) {
        CallObjectHolder memory coh = deferredCalls[seqNumber];
        return (coh.initialized, coh.callObj);
    }

    // push a call to the laminator
    // it can be pulled next block
    function push(bytes calldata input) public onlyOwner returns (uint256) {
        push(input, 1);
    }

    /// if you want to push a call with no delay, use this function and use 0 as the delay
    /// if you want to push a call with a weird delay, use this function and use the delay you want :)
    function push(bytes calldata input, uint32 delay) public onlyOwner returns (uint256) {
        CallObject memory callObj = abi.decode(input, (CallObject));
        uint256 currentSequenceNumber = sequenceNumber++;
        deferredCalls[currentSequenceNumber] =
            CallObjectHolder({initialized: true, firstCallableBlock: block.number + delay, callObj: callObj});
        emit CallPushed(callObj, currentSequenceNumber);
        return currentSequenceNumber;
    }

    function pull(uint256 seqNumber) public returns (bytes memory) {
        CallObjectHolder memory coh = deferredCalls[seqNumber];

        require(deferredCalls[seqNumber].initialized, "Proxy: Invalid sequence number");

        require(block.number >= coh.firstCallableBlock, "Proxy: Too early to pull this sequence number");

        CallObject memory callToMake = coh.callObj;

        (bool success, bytes memory returnvalue) =
            coh.callObj.addr.call{gas: coh.callObj.gas, value: coh.callObj.amount}(coh.callObj.callvalue);

        require(success, "Proxy: Call failed");

        emit CallPulled(callToMake, seqNumber);

        // some cleanup :)
        delete deferredCalls[seqNumber].callObj;
        delete deferredCalls[seqNumber];

        return returnvalue;
    }

    function execute(bytes calldata input) public onlyOwner returns (bytes memory) {
        CallObject memory callToMake = abi.decode(input, (CallObject));
        (bool success, bytes memory returnvalue) =
            callToMake.addr.call{gas: callToMake.gas, value: callToMake.amount}(callToMake.callvalue);
        require(success, "Proxy: Immediate call failed");
        emit CallExecuted(callToMake);
        return returnvalue;
    }
}
