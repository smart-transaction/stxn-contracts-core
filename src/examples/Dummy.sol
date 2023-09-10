// SPDX-License-Identifier: UNLICENSED
pragma solidity ^=0.8.20;

// dummy for laminator tests
contract Dummy {
    event DummyEvent(uint256 arg);

    function emitArg(uint256 arg) public {
        emit DummyEvent(arg);
    }

    function reverter() public pure {
        revert("Dummy: revert");
    }
}
