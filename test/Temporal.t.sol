// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "../src/timetravel/CallBreaker.sol";
import "../src/examples/TemporalStates.sol";

// Use the callbreaker to verify a temporal state
// The user should push a call to the laminated mempool that has a temporal state
// At different blocktimes, the callbreaker should return different values
// The callbreaker should return the correct value at the correct time using a partial function
contract TemporalStates {

}