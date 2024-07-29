// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {LaminatorHarness} from "./Laminator.t.sol";
import {CallBreaker} from "src/timetravel/CallBreaker.sol";

contract GasSnapshot is Test {
    LaminatorHarness laminator;
    CallBreaker callBreaker;

    // TODO: Finish gas snapshots
    function setUp() public {
        callBreaker = new CallBreaker();
        laminator = new LaminatorHarness(address(callBreaker));
    }

    function test_getOrCreateProxy() public {
        laminator.harness_getOrCreateProxy(address(this));
    }
}
