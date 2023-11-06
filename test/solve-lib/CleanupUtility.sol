// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../../src/TimeTypes.sol";
import "../../src/timetravel/CallBreaker.sol";

contract CleanupUtility {
    function preClean(
        address callBreaker,
        address selfcheckout,
        address pusherLaminated,
        uint256 laminatorSequenceNumber,
        bytes calldata callValue
    ) public {
        CallBreaker cb = CallBreaker(payable(callBreaker));

        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "cleanup(address,address,address,uint256,bytes)",
                callBreaker,
                selfcheckout,
                pusherLaminated,
                laminatorSequenceNumber,
                callValue
                )
        });
        CallObjectWithIndex memory callObjWithIndex = CallObjectWithIndex({callObj: callObj, index: 4});
        bytes memory ret = cb.enterPortal(abi.encode(callObjWithIndex));
    }

    function cleanup(
        address callBreaker,
        address selfcheckout,
        address pusherLaminated,
        uint256 laminatorSequenceNumber,
        bytes calldata callValue
    ) public {
        // this one should call enterportal and throw out the result 3 times.
        // this fixes the accounting for all the extra things we called.
        // i don't think there need to be any permissions here but i could be wrong.
        // i think there are also probably some exploits with ordering going on in here?

        CallBreaker cb = CallBreaker(payable(callBreaker));

        CallObject memory callObj =
            CallObject({amount: 0, addr: address(selfcheckout), gas: 1000000, callvalue: callValue});
        CallObjectWithIndex memory callObjWithIndex = CallObjectWithIndex({callObj: callObj, index: 2});
        bytes memory ret = cb.enterPortal(abi.encode(callObjWithIndex));

        // next with pull.
        callObj = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        callObjWithIndex = CallObjectWithIndex({callObj: callObj, index: 1});

        ret = cb.enterPortal(abi.encode(callObjWithIndex));

        // finally with preclean to finish the stack
        callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "preClean(address,address,address,uint256,bytes)",
                callBreaker,
                selfcheckout,
                pusherLaminated,
                laminatorSequenceNumber,
                callValue
                )
        });
        callObjWithIndex = CallObjectWithIndex({callObj: callObj, index: 0});
        ret = cb.enterPortal(abi.encode(callObjWithIndex));
    }
}
