// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/timetravel/CallBreaker.sol";
import "test/examples/FlashPill.sol";

contract FlashPillTest is Test {
    CallBreaker private callbreaker;
    FlashPill private flashpill;

    function setUp() public {
        callbreaker = new CallBreaker();
        flashpill = new FlashPill(address(callbreaker));
    }

    // @TODO: Complete FlashPill example
    function test() public pure {
        assert(true);
    }
}
