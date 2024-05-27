// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {AssociatedDataStorage, AssociatedDataLib} from "../src/CallBreakerTypes.sol";

contract AssociatedDataStorageTest is Test {
    AssociatedDataStorage assocData;

    function setUp() public {}

    function test_assocStore(bytes memory data) public {
        vm.assume(data.length < AssociatedDataLib.LARGE_DATA_SIZE_CAP);

        assertFalse(assocData.set());

        assocData.store(data);

        assertTrue(assocData.set());
        assertEq(assocData.load(), data);
    }
}
