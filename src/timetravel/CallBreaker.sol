// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "../TimeTypes.sol";
import "./CallBreakerStorage.sol";

contract CallBreaker is CallBreakerStorage {
    /// @dev Error thrown when there are no return values left
    /// @dev Selector 0xc8acbe62
    error OutOfReturnValues();
    /// @dev Error thrown when there is not enough Ether left
    /// @dev Selector 0x75483b53
    error OutOfEther();
    /// @dev Error thrown when a call fails
    /// @dev Selector 0x3204506f
    error CallFailed();
    /// @dev Error thrown when call-return pairs don't have balanced counts
    /// @dev Selector 0x8489203a
    error TimeImbalance();
    /// @dev Error thrown when receiving empty calldata
    /// @dev Selector 0xc047a184
    error EmptyCalldata();
    /// @dev Error thrown when there is a length mismatch
    /// @dev Selector 0xff633a38
    error LengthMismatch();
    /// @dev Error thrown when call verification fails
    /// @dev Selector 0xcc68b8ba
    error CallVerificationFailed();
    /// @dev Error thrown when index of the callObj doesn't match the index of the returnObj
    /// @dev Selector 0xdba5f6f9
    error IndexMismatch(uint256, uint256);
    /// @dev Error thrown when key already exists in the associatedDataStore
    /// @dev Selector 0xaa1ba2f8
    error KeyAlreadyExists();
    /// @dev Error thrown when a nonexistent key is fetched from the associatedDataStore
    /// @dev Selector 0xf7c16a37
    error NonexistentKey();
    /// @dev Caller must be EOA
    /// @dev Selector 0x09d1095b
    error MustBeEOA();

    error CallPositionFailed(CallObject, uint256);

    /// @notice Emitted when a new key-value pair is inserted into the associatedDataStore
    event InsertIntoAssociatedDataStore(bytes32 key, bytes value);

    /// @notice Emitted when a value is fetched from the associatedDataStore using a key
    event FetchFromAssociatedDataStore(bytes32 key);

    /// @notice Emitted when the enterPortal function is called
    /// @param callObj The CallObject instance containing details of the call
    /// @param returnvalue The ReturnObject instance containing details of the return value
    /// @param index The index of the return value in the returnStore
    event EnterPortal(CallObject callObj, ReturnObject returnvalue, uint256 index);

    /// @notice Emitted when the verifyStxn function is called
    event VerifyStxn();

    event CallPopulated(CallObject callObj, uint256 index);

    /// @notice Initializes the contract; sets the initial portal status to closed
    constructor() {
        _setPortalClosed();
    }

    modifier ensureTurnerOpen() {
        if (!isPortalOpen()) {
            revert PortalClosed();
        }
        _;
    }

    /// NOTE: Expect calls to arrive with non-null msg.data
    receive() external payable {
        revert EmptyCalldata();
    }

    /// @notice Fetches the value associated with a given key from the associatedDataStore
    /// @param key The key whose associated value is to be fetched
    /// @return The value associated with the given key
    function fetchFromAssociatedDataStore(bytes32 key) public view returns (bytes memory) {
        if (!associatedDataStore[key].set) {
            revert NonexistentKey();
        }
        return associatedDataStore[key].value;
    }

    function getPair(uint256 i) public view returns (CallObject memory, ReturnObject memory) {
        return (callStore[i], returnStore[i]);
    }

    function getCallListAt(uint256 i) public view returns (Call memory) {
        return callList[i];
    }

    event Log(uint256 i);

    /// very important to document this
    /// @notice Searches the callList for all indices of the callId
    /// @dev This is very gas-extensive as it computes in O(n)
    /// @param callObj The callObj to search for
    function getCompleteCallIndex(CallObject memory callObj) public view returns (uint256[] memory) {
        bytes32 callId = keccak256(abi.encode(callObj));
        uint256[] memory index = new uint256[](callList.length);
        for (uint256 i = 0; i < callList.length; i++) {
            if (callList[i].callId == callId) {
                index[i] = i;
            }
        }
        return index;
    }

    function getCallIndex(CallObject memory callObj) public view returns (uint256[] memory) {
        bytes32 callId = keccak256(abi.encode(callObj));
        // look up this callid in hintdices
        uint256[] storage hintdices = hintdicesStore[callId].indices;
        // validate that the right callid lives at these hintdices
        for (uint256 i = 0; i < hintdices.length; i++) {
            uint256 hintdex = hintdices[i];
            Call memory call = callList[hintdex];
            if (call.callId != callId) {
                revert CallPositionFailed(callObj, hintdex);
            }
        }
        return hintdices;
    }

    function getCurrentlyExecuting() public view returns (uint256) {
        if (!isPortalOpen()) {
            revert PortalClosed();
        }
        return executingCallIndex();
    }

    // @dev convert a reverse index into a forward index
    // or a forward index into a reverse index
    // looking at the callstore and returnstore indices
    function reverseIndex(uint256 index) public view returns (uint256) {
        if (index >= callStore.length) {
            revert IndexMismatch(index, callStore.length);
        }
        return returnStore.length - index - 1;
    }

    // verify
    // a .  11 (user doing some logic)
    // b .  22 (solver doing some bs)
    // c .  33 (user doing some asserts)
    // d .  44 (solver doing more bs)

    // EXAMPLE: user's desires:
    // wants to allow: a d b c (arbitrary shit between a and c)
    //     this is fine:
    //     a pops c
    //     db handle popping themselves
    //     c pops a
    // wants to allow: a b c d (arbitrary backrun)
    //     this is *not* currently fine:
    //     a pops c
    //     b pops itself
    //     what pops d? something before a must pop d. what goes before a? that's an illegal frontrun.
    //     a cannot pop d because a can't know about d because d is arbitrary code provided at solve-time
    //     c pops a
    // want to allow: a c b c d
    //     (this just works, when_was_it_called(c) can be either, enterportal accounting is basically the same
    // want to prevent: c d b a: c before a (tricking the timeturner)
    //     c pops a
    //     db pop themselves
    //     a pops c
    //     this can be checked by setting a bool in a, and then checking and unsetting it in c- so we're okay in the current paradigm, although it is sucky and ugly
    // wants to prevent: e a d b c (no frontrunning pls)
    //     you can't prevent this without indices:
    //     c pops a
    //     add some (legal) backrun, g, after c
    //     g pops e (e also pops g)
    //     everything works :| unfortunately
    //     this is fixed by adding indices :)
    // want to prevent: a b d e (a ever being run without its call to c, which enforces invariants)
    //     this is fixed with the timeturner- if a enterportals on c, c has to be called in verify, otherwise everything reverts

    // in a, we want to see c executed at some point
    // in a, we want nothing before a
    // in a, call enterportal(c)
    // in c, call enterportal(a)

    // proposal: provide an index from the front, an index from the back, or a "hintdex"- the user wants to know the location of certain calls at solvetime, the solver provides that?
    // look up return value and check into enterportal by index
    // have a utility function that converts reverse indices into forward indices
    // put assertions on relative ordering into userspace code! say a < c explicitly.
    // same call twice, two different returns- how to disambiguate? indices and comparisons!
    // need to be able to say that

    // i call enterportal with a, index 1
    // enterportal checks that a is at index 1, returns the return value of a back to itself
    // i call enterportal with c, index when_was_it_called(c) <- this is just a hashtable lookup in associateddata (or just another hashmap)
    // enterportal checks that c is at index when_was_it_called(c), returns the return value of c back to itself
    // verify handles actually making sure c is called at that index
    // check 1 < when_was_it_called(c)
    // xiangan's example: ind(a) + 2 == when_was_it_called(c)

    // b and d need to handle their own enterportal and index calls- this is fine.
    // no frontruns allowed- a is always 1
    // backruns are fine
    // arbitrary code is fine in between a and c and after c, it just needs to pop itself off the stack with knowledge of indices
    // reshuffling a and c is no longer okay- a must be called before c, checked in a

    // about hintdices:
    // a will say ind(c) = associateddatafetch("whenwascccalled")
    // a will assert ind(c) > 1 (1 is ind(a), a knows this, because c is checking it already through the callbreaker)
    // enterportal(a, 1) will check in verify's call that a actually gets executed at index(1)
    // enterportal(c, ind(c)) will check also in enterportal + verify's call using verify bookkeeping that c is executed at ind(c)
    // it's fine that the solver is providing this value- a is checking the relative value to other calls, and enterportal is checking that the call happened there.

    // OKAY! as of nov 8, hintdices are broken :|
    // consider a language:
    // aacac (legal)
    // ababcabc (legal)
    // ababacab (illegal) (a must always be followed by a c)
    // what you want is to be able to express regular expressions of calls, ideally.
    // how do you do this?

    // /// @notice Executes a call and returns a value from the record of return values.
    // /// @dev This function also does some accounting to track the occurrence of a given pair of call and return values.
    // /// It is called as reentrancy in order to balance the calls of the solution and make things validate.
    // /// @param input The call to be executed, structured as a CallObjectWithIndex.
    // /// @return The return value from the record of return values.
    // /// TODO: make this do lookups in an array instead of in a hashmap. mark "done" with a bool, and then just iterate over the array to check what's filled
    // /// TODO: determine if this is gas-optimal (hi @audit)
    function getReturnValue(bytes calldata input) external payable onlyPortalOpen returns (bytes memory) {
        // Decode the input to obtain the CallObject and calculate a unique ID representing the call-return pair
        CallObjectWithIndex memory callObjWithIndex = abi.decode(input, (CallObjectWithIndex));
        ReturnObject memory thisReturn = getReturn(callObjWithIndex.index);
        emit EnterPortal(callObjWithIndex.callObj, thisReturn, callObjWithIndex.index);
        return thisReturn.returnvalue;
    }

    /// @notice Verifies that the given calls, when executed, gives the correct return values
    /// @dev SECURITY NOTICE: This function is only callable when the portal is closed. It requires the caller to be an EOA.
    /// @param callsBytes The bytes representing the calls to be verified
    /// @param returnsBytes The bytes representing the returns to be verified against
    /// @param associatedData Bytes representing associated data with the verify call, reserved for tipping the solver
    function verify(
        bytes memory callsBytes,
        bytes memory returnsBytes,
        bytes memory associatedData,
        bytes memory hintdices
    ) external payable onlyPortalClosed {
        _setPortalOpen();
        if (msg.sender.code.length != 0) {
            revert MustBeEOA();
        }

        CallObject[] memory calls = abi.decode(callsBytes, (CallObject[]));
        ReturnObject[] memory returnValues = abi.decode(returnsBytes, (ReturnObject[]));

        if (calls.length != returnValues.length) {
            revert LengthMismatch();
        }

        _resetTraceStoresWith(calls, returnValues);
        _populateAssociatedDataStore(associatedData);
        _populateHintdices(hintdices);
        _populateCallIndices();

        for (uint256 i = 0; i < calls.length; i++) {
            _setCurrentlyExecutingCallIndex(i);
            _executeAndVerifyCall(i);
        }

        _cleanUpStorage();
        _setPortalClosed();
        emit VerifyStxn();
    }

    function _populateCallIndices() internal {
        for (uint256 i = 0; i < callStore.length; i++) {
            Call memory call = Call({callId: keccak256(abi.encode(callStore[i])), index: i});
            callList.push(call);
            emit CallPopulated(callStore[i], i);
        }
    }

    function _resetTraceStoresWith(CallObject[] memory calls, ReturnObject[] memory returnValues) internal {
        delete callStore;
        delete returnStore;
        for (uint256 i = 0; i < calls.length; i++) {
            callStore.push(calls[i]);
            returnStore.push(returnValues[i]);
        }
    }

    /// @dev Executes a single call and verifies the result by generating the call-return pair ID
    /// @param i The index of the CallObject and returnobject to be executed and verified
    function _executeAndVerifyCall(uint256 i) internal {
        (CallObject memory callObj, ReturnObject memory retObj) = getPair(i);
        if (callObj.amount > address(this).balance) {
            revert OutOfEther();
        }

        (bool success, bytes memory returnvalue) =
            callObj.addr.call{gas: callObj.gas, value: callObj.amount}(callObj.callvalue);
        if (!success) {
            revert CallFailed();
        }

        if (keccak256(retObj.returnvalue) != keccak256(returnvalue)) {
            revert CallVerificationFailed();
        }
    }

    /// @dev Cleans up storage by resetting returnStore
    function _cleanUpStorage() internal {
        delete callStore;
        delete returnStore;
        delete callList;
        for (uint256 i = 0; i < associatedDataKeyList.length; i++) {
            delete associatedDataStore[associatedDataKeyList[i]];
        }
        delete associatedDataKeyList;

        for (uint256 i = 0; i < hintdicesStoreKeyList.length; i++) {
            delete hintdicesStore[hintdicesStoreKeyList[i]];
        }
        delete hintdicesStoreKeyList;

        // Transfer remaining ETH balance to the block builder
        address payable blockBuilder = payable(block.coinbase);
        blockBuilder.transfer(address(this).balance);
    }

    function expectCallAt(CallObject memory callObj, uint256 index) internal view {
        if (callStore[index].addr != callObj.addr) {
            revert CallPositionFailed(callObj, index);
        }
    }

    // @dev Helper function to fetch and remove the last ReturnObject from the storage
    function getReturn(uint256 index) internal view returns (ReturnObject memory) {
        return returnStore[index];
    }

    /// @notice Populates the associatedDataStore with a list of key-value pairs
    /// @param encodedData The abi-encoded list of (bytes32, bytes32) key-value pairs
    function _populateAssociatedDataStore(bytes memory encodedData) internal {
        // Decode the input data into an array of (bytes32, bytes32) pairs
        (bytes32[] memory keys, bytes[] memory values) = abi.decode(encodedData, (bytes32[], bytes[]));

        // Check that the keys and values arrays have the same length
        if (keys.length != values.length) {
            revert LengthMismatch();
        }

        // Iterate over the keys and values arrays and insert each pair into the associatedDataStore
        for (uint256 i = 0; i < keys.length; i++) {
            _insertIntoAssociatedDataStore(keys[i], values[i]);
        }
    }

    function _populateHintdices(bytes memory encodedData) internal {
        // Decode the input data into an array of (bytes32, bytes32) pairs
        (bytes32[] memory keys, uint256[] memory values) = abi.decode(encodedData, (bytes32[], uint256[]));

        // Check that the keys and values arrays have the same length
        if (keys.length != values.length) {
            revert LengthMismatch();
        }

        // Iterate over the keys and values arrays and insert each pair into the hintdices
        for (uint256 i = 0; i < keys.length; i++) {
            _insertIntoHintdices(keys[i], values[i]);
        }
    }

    function _insertIntoHintdices(bytes32 key, uint256 value) internal {
        // If the key doesn't exist in the hintdices, initialize it
        if (!hintdicesStore[key].set) {
            hintdicesStore[key].set = true;
            hintdicesStore[key].indices = new uint256[](0);
            hintdicesStoreKeyList.push(key);
        }

        // Append the value to the list of values associated with the key
        hintdicesStore[key].indices.push(value);
    }

    /// @notice Inserts a pair of bytes32 into the associatedDataStore and associatedDataKeyList
    /// @param key The key to be inserted into the associatedDataStore
    /// @param value The value to be associated with the key in the associatedDataStore
    function _insertIntoAssociatedDataStore(bytes32 key, bytes memory value) internal {
        // Check if the key already exists in the associatedDataStore
        if (associatedDataStore[key].set) {
            revert KeyAlreadyExists();
        }

        emit InsertIntoAssociatedDataStore(key, value);
        // Insert the key-value pair into the associatedDataStore
        associatedDataStore[key].set = true;
        associatedDataStore[key].value = value;

        // Add the key to the associatedDataKeyList
        associatedDataKeyList.push(key);
    }
}
