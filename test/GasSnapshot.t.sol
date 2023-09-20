// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import {Test} from "forge-std/Test.sol";
import {LaminatorHarness} from "./Laminator.t.sol";

contract GasSnapshot is Test {
    LaminatorHarness laminator;

    function setUp() public {
        laminator = new LaminatorHarness();
    }

    function test_getOrCreateProxy() public {
        laminator.harness_getOrCreateProxy(address(this));
    }
}