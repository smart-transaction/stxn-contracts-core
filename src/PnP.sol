// SPDX-License-Identifier: MIT
// pragma solidity ^0.8.13;

import "./TimeTurner.sol";

contract PnPTurner {
    address private _timeturnerAddress;

    constructor(address timeturnerLocation) {
        _timeturnerAddress = timeturnerLocation;
    }

    function p(uint256 input, uint256 index) external returns (bool) {

    }

    function np(uint256 input) external returns (uint256 index) {

    }

    function timeTurnerNP(uint256 input) external returns (uint256 index) {
    }
}