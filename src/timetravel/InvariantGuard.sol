// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "./CallBreaker.sol";
import "../lamination/LaminatedProxy.sol";

contract InvariantGuard is CallBreaker {
    LaminatedProxy laminator;

    constructor(address _laminator) {
        laminator = LaminatedProxy(payable(_laminator));
    }

    function noFrontRunInThisPull() public {
        // ensure we're in the timeturner context
        ensureTurnerOpen();

        bytes memory snumbytes = this.fetchFromAssociatedDataStore(keccak256(abi.encodePacked("pullIndex")));

        uint256 snum = abi.decode(snumbytes, (uint256));

        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(laminator),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", snum)
        });

        uint256[] memory cinds = this.getCallIndices(callObj);
        require(cinds.length == 1, "InvariantGuard: noFrontRunInThisPull expected exactly one call index");
        require(cinds[0] == 0, "InvariantGuard: noFrontRunInThisPull expected call index 0");
    }
}
