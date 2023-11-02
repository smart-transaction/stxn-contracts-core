// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.2 <0.9.0;

import "../timetravel/CallBreaker.sol";

contract Tips {
    event Tip(address indexed from, address indexed to, uint256 amount);
    
    CallBreaker public callbreaker;

    constructor(address _callbreaker) {
        callbreaker = CallBreaker(payable(_callbreaker));
    }

    receive() external payable {
        bytes32 tipAddrKey = keccak256(abi.encodePacked("tipYourBartender"));
        bytes memory tipAddrBytes = callbreaker.fetchFromAssociatedDataStore(tipAddrKey);
        address tipAddr = abi.decode(tipAddrBytes, (address));
        payable(tipAddr).transfer(msg.value);
        emit Tip(msg.sender, address(this), msg.value);
    }
}
