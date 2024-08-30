// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./LaminatedStorage.sol";
import "openzeppelin/security/ReentrancyGuard.sol";

contract LaminatedProxy is LaminatedStorage, ReentrancyGuard {
    /// @notice Some functions must be called by the laminator or the proxy only.
    /// @dev Selector 0xfc51f672
    error NotLaminatorOrProxy();

    /// @notice Some functions must be called by the call breaker only.
    /// @dev Selector 0x4c0f7a6c
    error NotCallBreaker();

    /// @notice Some functions must be called by the laminator only.
    /// @dev Selector 0x91c58dcd
    error NotLaminator();

    /// @notice Some functions must be called by the laminator or the proxy only.
    /// @dev Selector 0xbf10dd3a
    error NotProxy();

    /// @notice Some functions must be called by the owner only.
    /// @dev Selector 0xbf10dd3a
    error NotOwner();

    /// @notice Calls pulled from the mempool must have been previously pushed and initialized.
    /// @dev Selector 0x1c72fad4
    error Uninitialized();

    /// @notice Calls pulled from the mempool must be after a certain user-specified delay.
    /// @dev Selector 0x085de625
    error TooEarly();

    /// @notice Call pulled from the mempool failed to execute.
    /// @dev Selector 0x3204506f
    error CallFailed();

    /// @notice The sequence number of a deferred call must be set before it can be executed.
    error NotExecuting();

    /// @notice Call has already been pulled and executed.
    /// @dev Selector 0x0dc10197
    error AlreadyExecuted();

    /// @dev Emitted when a function call is deferred and added to the queue.
    /// @param callObjs The CallObject[] containing details of the deferred function call.
    /// @param sequenceNumber The sequence number assigned to the deferred function call.
    event CallPushed(CallObject[] callObjs, uint256 sequenceNumber);

    /// @dev Emitted when a deferred function call is executed from the queue.
    /// @param callObjs The CallObject[] containing details of the executed function call.
    /// @param sequenceNumber The sequence number of the executed function call.
    event CallPulled(CallObject[] callObjs, uint256 sequenceNumber);

    /// @dev Emitted when a function call is executed immediately, without being deferred.
    /// @param callObj The CallObjects containing details of the executed function calls.
    event CallExecuted(CallObject callObj);

    /// @dev The block at which a call becomes executable.
    /// @param callableBlock The block number that is now callable.
    /// @param currentBlock The current block number.
    event CallableBlock(uint256 callableBlock, uint256 currentBlock);

    /// @dev Modifier to make a function callable only by the proxy.
    ///      Reverts the transaction if the sender is not the proxy.
    modifier onlyProxy() {
        if (msg.sender != address(this)) {
            revert NotProxy();
        }
        _;
    }

    /// @dev Modifier to make a function callable only by the laminator.
    ///      Reverts the transaction if the sender is not the laminator.
    modifier onlyLaminator() {
        if (msg.sender != address(laminator())) {
            revert NotLaminator();
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner()) {
            revert NotOwner();
        }
        _;
    }

    /// @dev Modifier to make a function callable only by the laminator or proxy.
    ///      Reverts the transaction if the sender is not the laminator or proxy.
    modifier onlyLaminatorOrProxy() {
        if (msg.sender != address(laminator()) && msg.sender != address(this)) {
            revert NotLaminatorOrProxy();
        }
        _;
    }

    /// @dev Modifier to make a function callable only by the call breaker.
    ///      Reverts the transaction if the sender is not the call breaker.
    modifier onlyCallBreaker() {
        if (msg.sender != address(callBreaker()) && msg.sender != address(this)) {
            revert NotCallBreaker();
        }
        _;
    }

    modifier onlyWhileExecuting() {
        if (!isCallExecuting()) {
            revert NotExecuting();
        }
        _;
    }

    /// @notice Constructs a new contract instance - usually called by the Laminator contract
    /// @dev Initializes the contract, setting the owner and laminator addresses.
    /// @param _laminator The address of the laminator contract.
    /// @param _callBreaker The address of the call breaker contract.
    /// @param _owner The address of the contract's owner.
    constructor(address _laminator, address _callBreaker, address _owner) {
        _setOwner(_owner);
        _setLaminator(_laminator);
        _setCallBreaker(_callBreaker);
    }

    /// @notice Allows the contract to receive Ether.
    /// @dev The received Ether can be spent via the `execute`, `push`, and `pull` functions.
    receive() external payable {}

    /// @notice Executes a deferred function call that has been pushed to the contract.
    /// @dev Executes the deferred call specified by the sequence number `seqNumber`.
    ///      This function performs a series of checks before calling `_execute` to
    ///      execute the deferred call. It emits a `CallPulled` event and deletes
    ///      the deferred call object from the `deferredCalls` mapping.
    /// @param seqNumber The sequence number of the deferred call to be executed.
    /// @return returnValue The return value of the executed deferred call.
    function pull(uint256 seqNumber) external nonReentrant onlyCallBreaker returns (bytes memory returnValue) {
        CallObjectHolderStorage storage cohStorage = _deferredCalls[seqNumber];
        _checkPrePush(cohStorage);

        cohStorage.executed = true;
        _setCurrentlyExecutingSeqNum(seqNumber);
        _setCurrentlyExecutingCallIndex(0);
        _setExecuting();
        CallObjectHolder memory coh = cohStorage.load();
        emit CallableBlock(coh.firstCallableBlock, block.number);

        returnValue = _executeAll(coh.callObjs);
        emit CallPulled(coh.callObjs, seqNumber);
        _setFree();
    }

    /// @notice Executes a function call immediately.
    /// @dev Decodes the provided `input` into a CallObject and then calls `_execute`.
    ///      Can only be invoked by the owner of the contract.
    /// @param input The encoded CallObject containing information about the function call to execute.
    /// @return returnValue The return value from the executed function call.
    function execute(bytes calldata input) external onlyLaminator nonReentrant returns (bytes memory) {
        CallObject[] memory callsToMake = abi.decode(input, (CallObject[]));
        return _executeAll(callsToMake);
    }

    /// @notice Copies the current job with a specified delay and condition.
    /// @dev This function can only be called by the LaminatedProxy contract itself.
    /// @param delay The number of blocks to delay before the copied job can be executed.
    /// @param shouldCopy The condition under which the job should be copied.
    /// @return The sequence number of the copied job.
    /// @custom:reverts It reverts if the sequence number is not set or if the sender is not the proxy.
    function copyCurrentJob(uint256 delay, bytes calldata shouldCopy) external onlyWhileExecuting returns (uint256) {
        if (msg.sender != address(this)) {
            revert NotProxy();
        }
        return _copyJob(executingSequenceNumber(), delay, shouldCopy);
    }

    /// @notice Cancels all pending calls
    /// @dev Sets the executed flag to true for all pending calls
    function cancelAllPending() external onlyOwner {
        uint256 _count = nextSequenceNumber();
        for (uint256 i = executingSequenceNumber(); i < _count; i++) {
            if (_deferredCalls[i].executed == false) {
                _deferredCalls[i].executed = true;
            }
        }
    }

    function cancelPending(uint256 callSequenceNumber) external onlyOwner {
        if (_deferredCalls[callSequenceNumber].executed == false && _deferredCalls[callSequenceNumber].initialized) {
            _deferredCalls[callSequenceNumber].executed = true;
        }
    }

    /// @notice Views a deferred function call with a given sequence number.
    /// @dev Returns a tuple containing a boolean indicating whether the deferred call exists,
    ///      and the CallObject containing details of the deferred function call.
    /// @param seqNumber The sequence number of the deferred function call to view.
    /// @return exists A boolean indicating whether the deferred call exists.
    /// @return callObj The CallObject containing details of the deferred function call.
    function viewDeferredCall(uint256 seqNumber) public view returns (bool, bool, CallObject[] memory) {
        CallObjectHolder memory coh = deferredCalls(seqNumber);
        return (coh.initialized, coh.executed, coh.callObjs);
    }

    function getExecutingCallObject() public view onlyWhileExecuting returns (CallObject memory) {
        return _deferredCalls[executingSequenceNumber()].getCallObj(executingCallIndex()).load();
    }

    function getExecutingCallObjectHolder() public view onlyWhileExecuting returns (CallObjectHolder memory) {
        return deferredCalls(executingSequenceNumber());
    }

    /// @notice Pushes a deferred function call to be executed after a certain delay.
    /// @dev Adds a new CallObject to the `deferredCalls` mapping and emits a CallPushed event.
    ///      The function can only be called by the Laminator or the LaminatedProxy contract itself.
    ///      It can also be called re-entrantly to enable the contract to do cronjobs with tail recursion.
    /// @param input The encoded CallObject containing information about the function call to defer.
    /// @param delay The number of blocks to delay before the function call can be executed.
    ///      Use 0 for no delay.
    /// @return callSequenceNumber The sequence number assigned to this deferred call.
    function push(bytes memory input, uint256 delay) public onlyLaminatorOrProxy returns (uint256 callSequenceNumber) {
        CallObjectHolder memory holder;
        holder.callObjs = abi.decode(input, (CallObject[]));
        callSequenceNumber = count();
        holder.initialized = true;
        holder.executed = false;
        holder.firstCallableBlock = block.number + delay;
        _deferredCalls[callSequenceNumber].store(holder);

        emit CallableBlock(block.number + delay, block.number);
        emit CallPushed(holder.callObjs, callSequenceNumber);
        _incrementSequenceNumber();
    }

    /// @dev Executes the function call specified by the CallObject `callToMake`.
    ///      Emits a `CallExecuted` event upon successful execution.
    /// @param callsToMake The CallObject containing information about the function call to execute.
    /// @return returnValue The return value from the executed function call.
    function _executeAll(CallObject[] memory callsToMake) internal returns (bytes memory) {
        ReturnObject[] memory returnObjs = new ReturnObject[](callsToMake.length);
        for (uint256 i = 0; i < callsToMake.length; i++) {
            _setCurrentlyExecutingCallIndex(i);
            returnObjs[i] = ReturnObject({returnvalue: _execute(callsToMake[i])});
        }
        return abi.encode(returnObjs);
    }

    /// @dev Executes a single function call specified by the CallObject `callToMake`.
    ///      Emits a `CallExecuted` event upon successful execution.
    /// @param callToMake The CallObject containing information about the function call to execute.
    /// @return returnvalue The return value from the executed function call.
    function _execute(CallObject memory callToMake) internal returns (bytes memory) {
        bool success;
        bytes memory returnvalue;

        (success, returnvalue) =
            callToMake.addr.call{gas: callToMake.gas, value: callToMake.amount}(callToMake.callvalue);
        if (!success) {
            revert CallFailed();
        }

        emit CallExecuted(callToMake);
        return returnvalue;
    }

    /// @dev Copies a job with a specified delay and condition.
    /// @param seqNumber The sequence number of the job to be copied.
    /// @param delay The number of blocks to delay before the copied job can be executed.
    /// @param shouldCopy The condition under which the job should be copied.
    /// @return The sequence number of the copied job.
    function _copyJob(uint256 seqNumber, uint256 delay, bytes memory shouldCopy) internal returns (uint256) {
        if (shouldCopy.length != 0) {
            CallObject memory callObj = abi.decode(shouldCopy, (CallObject));
            bytes memory result = _execute(callObj);
            bool shouldContinue = abi.decode(result, (bool));
            if (!shouldContinue) {
                return 0;
            }
        }

        CallObjectHolderStorage storage coh = _deferredCalls[seqNumber];
        _checkInitialized(coh);

        return push(abi.encode(coh.load().callObjs), delay);
    }

    /// @dev Safety checks before pushing calls to the LaminatedProxy
    /// @param coh The CallObjectHolder to be checked.
    function _checkPrePush(CallObjectHolderStorage storage coh) internal view {
        _checkInitialized(coh);
        _checkExecuted(coh);
        _checkCallTime(coh);
    }

    /// @dev Checks if the CallObjectHolder is initialized.
    /// @param coh The CallObjectHolder to be checked.
    function _checkInitialized(CallObjectHolderStorage storage coh) internal view {
        if (!coh.initialized) {
            revert Uninitialized();
        }
    }

    /// @dev Checks if the CallObjectHolder has already been executed.
    /// @param coh The CallObjectHolder to be checked.
    function _checkExecuted(CallObjectHolderStorage storage coh) internal view {
        if (coh.executed) {
            revert AlreadyExecuted();
        }
    }

    /// @dev Checks if the CallObjectHolder is ready to be executed based on the current block number.
    /// @param coh The CallObjectHolder to be checked.
    function _checkCallTime(CallObjectHolderStorage storage coh) internal view {
        if (coh.firstCallableBlock > block.number) {
            revert TooEarly();
        }
    }
}
