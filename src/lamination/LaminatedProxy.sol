// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// identical to the one from callbreaker
struct CallObject {
    uint256 amount;
    address addr;
    uint256 gas;
    /// should be abi encoded
    bytes callvalue;
}

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

    /// push a call to the laminator
    /// if you want to push a call with no delay, use this function and use 0 as the delay
    /// if you want to push a call with a weird delay, use this function and use the delay you want :)
    function push(bytes calldata input, uint32 delay) external onlyOwner returns (uint256) {
        CallObject memory callObj = abi.decode(input, (CallObject));
        uint256 currentSequenceNumber = sequenceNumber++;
        deferredCalls[currentSequenceNumber] =
            CallObjectHolder({initialized: true, firstCallableBlock: block.number + delay, callObj: callObj});
        emit CallPushed(callObj, currentSequenceNumber);
        return currentSequenceNumber;
    }

    function pull(uint256 seqNumber) external returns (bytes memory returnValue) {
        CallObjectHolder memory coh = deferredCalls[seqNumber];
        require(coh.initialized, "Proxy: Invalid sequence number");
        require(block.number >= coh.firstCallableBlock, "Proxy: Too early to pull this sequence number");

        returnValue = _execute(coh.callObj);

        emit CallPulled(coh.callObj, seqNumber);
        delete deferredCalls[seqNumber];
    }

    function execute(bytes calldata input) external onlyOwner returns (bytes memory) {
        CallObject memory callToMake = abi.decode(input, (CallObject));
        return _execute(callToMake);
    }

    function _execute(CallObject memory callToMake) internal returns (bytes memory) {
        (bool success, bytes memory returnvalue) =
            callToMake.addr.call{gas: callToMake.gas, value: callToMake.amount}(callToMake.callvalue);
        require(success, "Proxy: Immediate call failed");
        emit CallExecuted(callToMake);
        return returnvalue;
    }

    // this contract can receive eth but you have to spend it with execute/push/pull
    receive() external payable {}
}
