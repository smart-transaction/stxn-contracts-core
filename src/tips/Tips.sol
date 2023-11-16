// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.2 <0.9.0;

import "../timetravel/CallBreaker.sol";

contract Tips {
    event Tip(address indexed from, address indexed to, uint256 amount);

    event LogAmounts(uint256 msgvalue, uint256 balance);

    /// @dev Error thrown when receiving empty calldata
    /// @dev Selector 0xc047a184
    error EmptyCalldata();

    CallBreaker public callbreaker;

    constructor(address _callbreaker) {
        callbreaker = CallBreaker(payable(_callbreaker));
    }

    /// @dev Tips should be transferred from each LaminatorProxy to the solver via msg.value
    receive() external payable {
        emit LogAmounts(msg.value, address(this).balance);
        bytes32 tipAddrKey = keccak256(abi.encodePacked("tipYourBartender"));
        bytes memory tipAddrBytes = callbreaker.fetchFromAssociatedDataStore(tipAddrKey);
        address tipAddr = abi.decode(tipAddrBytes, (address));
        emit Tip(msg.sender, tipAddr, msg.value);
        payable(tipAddr).transfer(msg.value);
    }
}
