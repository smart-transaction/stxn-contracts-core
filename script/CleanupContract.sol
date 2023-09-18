// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../src/TimeTypes.sol";
import "../src/timetravel/CallBreaker.sol";

contract CleanupContract {
    function cleanup(address callBreaker, address selfcheckout, address pusherLaminated, uint256 laminatorSequenceNumber, uint256 btokenamount) public {
        // this one should call enterportal and throw out the result 3 times.
        // this fixes the accounting for all the extra things we called.
        // i don't think there need to be any permissions here but i could be wrong.
        // i think there are also probably some exploits with ordering going on in here?

        CallBreaker cb = CallBreaker(payable(callBreaker));

        // first with pull:
        CallObject memory callObj = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        // call enterPortal
        bytes memory ret = cb.enterPortal(abi.encode(callObj));

        // second with giveSomeBtokenToOwner
        callObj = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", btokenamount)
        });
        ret = cb.enterPortal(abi.encode(callObj));
        // return object is still nothing

        // finally with itself.
        callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("cleanup(address, address, address, uint256, uint256)", callBreaker, selfcheckout, pusherLaminated, laminatorSequenceNumber, btokenamount)
        });
        ret = cb.enterPortal(abi.encode(callObj));
    }
}