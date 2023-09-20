// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./LaminatedStorage.sol";

contract LaminatedProxy is LaminatedStorage {
    mapping(uint256 => CallObjectHolder) public deferredCalls;

    error NotLaminator();
    error Uninitialized();
    error TooEarly();
    error CallFailed();

    /// @dev Emitted when a function call is deferred and added to the queue.
    /// @param callObjs The CallObject[] containing details of the deferred function call.
    /// @param sequenceNumber The sequence number assigned to the deferred function call.
    event CallPushed(CallObject[] callObjs, uint256 sequenceNumber);

    /// @dev Emitted when a deferred function call is executed from the queue.
    /// @param callObjs The CallObject[] containing details of the executed function call.
    /// @param sequenceNumber The sequence number of the executed function call.
    event CallPulled(CallObject[] callObjs, uint256 sequenceNumber);

    /// @dev Emitted when a function call is executed immediately, without being deferred.
    /// @param callObj The CallObject containing details of the executed function call.
    event CallExecuted(CallObject callObj);

    /// @dev The block at which a call becomes executable.
    /// @param callableBlock The block number that is now callable.
    /// @param currentBlock The current block number.
    event CallableBlock(uint256 callableBlock, uint256 currentBlock);

    /// @dev Modifier to make a function callable only by the laminator.
    ///      Reverts the transaction if the sender is not the laminator.
    modifier onlyLaminator() {
        if(msg.sender != address(laminator())) revert NotLaminator();
        _;
    }

    /// @notice Constructs a new contract instance - usually called by the Laminator contract
    /// @dev Initializes the contract, setting the owner and laminator addresses.
    /// @param _laminator The address of the laminator contract.
    /// @param _owner The address of the contract's owner.
    constructor(address _laminator, address _owner) {
        _setOwner(_owner);
        _setLaminator(_laminator);
    }

    /// @notice Allows the contract to receive Ether.
    /// @dev The received Ether can be spent via the `execute`, `push`, and `pull` functions.
    receive() external payable {}


    /// @notice Views a deferred function call with a given sequence number.
    /// @dev Returns a tuple containing a boolean indicating whether the deferred call exists,
    ///      and the CallObject containing details of the deferred function call.
    /// @param seqNumber The sequence number of the deferred function call to view.
    /// @return exists A boolean indicating whether the deferred call exists.
    /// @return callObj The CallObject containing details of the deferred function call.
    function viewDeferredCall(uint256 seqNumber) public view returns (bool, CallObject[] memory) {
        CallObjectHolder memory coh = deferredCalls[seqNumber];
        return (coh.initialized, coh.callObjs);
    }

    /// @notice Pushes a deferred function call to be executed after a certain delay.
    /// @dev Adds a new CallObject to the `deferredCalls` mapping and emits a CallPushed event.
    ///      The function can only be called by the contract owner.
    /// @param input The encoded CallObject containing information about the function call to defer.
    /// @param delay The number of blocks to delay before the function call can be executed.
    ///      Use 0 for no delay.
    /// @return callSequenceNumber The sequence number assigned to this deferred call.
    function push(bytes calldata input, uint32 delay) external onlyLaminator returns (uint256 callSequenceNumber) {
        CallObject[] memory callObjs = abi.decode(input, (CallObject[]));
        callSequenceNumber = count();
        CallObjectHolder storage holder = deferredCalls[callSequenceNumber];
        holder.initialized = true;
        holder.firstCallableBlock = block.number + delay;
        for (uint i = 0; i < callObjs.length; ++i) {
            holder.callObjs.push(callObjs[i]);
        }

        emit CallableBlock(block.number + delay, block.number);
        emit CallPushed(callObjs, callSequenceNumber);
        _incrementSequenceNumber();
    }

    /// @notice Executes a deferred function call that has been pushed to the contract.
    /// @dev Executes the deferred call specified by the sequence number `seqNumber`.
    ///      This function performs a series of checks before calling `_execute` to
    ///      execute the deferred call. It emits a `CallPulled` event and deletes
    ///      the deferred call object from the `deferredCalls` mapping.
    /// @param seqNumber The sequence number of the deferred call to be executed.
    /// @return returnValue The return value of the executed deferred call.
    function pull(uint256 seqNumber) external returns (bytes memory returnValue) {
        CallObjectHolder memory coh = deferredCalls[seqNumber];
        if (!coh.initialized) revert Uninitialized();

        emit CallableBlock(coh.firstCallableBlock, block.number);
        if (coh.firstCallableBlock > block.number) revert TooEarly();

        returnValue = _execute(coh.callObjs);
        emit CallPulled(coh.callObjs, seqNumber);
        delete deferredCalls[seqNumber];
    }

    /// @notice Executes a function call immediately.
    /// @dev Decodes the provided `input` into a CallObject and then calls `_execute`.
    ///      Can only be invoked by the owner of the contract.
    /// @param input The encoded CallObject containing information about the function call to execute.
    /// @return returnValue The return value from the executed function call.
    function execute(bytes calldata input) external onlyLaminator returns (bytes memory) {
        CallObject[] memory callsToMake = abi.decode(input, (CallObject[]));
        return _execute(callsToMake);
    }

    /// @dev Executes the function call specified by the CallObject `callToMake`.
    ///      Emits a `CallExecuted` event upon successful execution.
    /// @param callsToMake The CallObject containing information about the function call to execute.
    /// @return returnValue The return value from the executed function call.
    function _execute(CallObject[] memory callsToMake) internal returns (bytes memory) {
        ReturnObject[] memory returnObjs = new ReturnObject[](callsToMake.length);
        for (uint256 i = 0; i < callsToMake.length; i++) {
            returnObjs[i] = ReturnObject({returnvalue: _executeSingle(callsToMake[i])});
        }
        return abi.encode(returnObjs);
    }

    function _executeSingle(CallObject memory callToMake) internal returns (bytes memory) {
        (bool success, bytes memory returnvalue) =
            callToMake.addr.call{gas: callToMake.gas, value: callToMake.amount}(callToMake.callvalue);
        if (!success) revert CallFailed();
        emit CallExecuted(callToMake);
        return returnvalue;
    }
}
