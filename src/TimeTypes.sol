// SPDX-License-Identifier: UNLICENSED
pragma solidity ^=0.8.20;

struct CallObject {
    uint256 amount;
    address addr;
    uint256 gas;
    /// should be abi encoded
    bytes callvalue;
}

struct ReturnObject {
    /// should be abi encoded
    bytes returnvalue;
}
