// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

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
