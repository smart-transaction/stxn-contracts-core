// this is cowswap, smart transaction style, and extremely badly designed/shitty.

// i'd like to transfer you 1 eth
// as long as you transfer me 3 dollars

// push: a call that can be pulled next block
// it transfers 1 erc20one to tx.origin
// and it checks that a call happens later to gibmeyourmoney (which transfers 2 erc20two over from tx.origin to self)!

// you can give me extra erc20two if you want. i don't mind :)

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../TimeTypes.sol";
import "../timetravel/CallBreaker.sol";

contract SelfCheckout {
    address owner;
    address callbreakerAddress;

    IERC20 atoken;
    IERC20 btoken;

    // hardcoded exchange rate (btokens per atoken)
    // one day this will be pulled from uniswap or something :3
    uint256 exchangeRate = 2;

    // your debt to the protocol denominated in btoken
    uint256 imbalance = 0;

    // tracks if we've called checkBalance yet. if not it needs to be.
    bool balanceScheduled = false;

    // when a debt is taken out of the protocol, it goes here. should be called right before executing a pull...
    address swapPartner;

    event DebugAddress(string message, address value);
    event DebugInfo(string message, string value);
    event DebugUint(string message, uint256 value);

    constructor(address _owner, address _atoken, address _btoken, address _callbreakerAddress) {
        owner = _owner;

        atoken = IERC20(_atoken);
        btoken = IERC20(_btoken);

        callbreakerAddress = _callbreakerAddress;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Proxy: Not the owner");
        _;
    }

    function setSwapPartner(address _swapPartner) public {
        swapPartner = _swapPartner;
    }

        event LogCallObj(CallObject callObj);


    // take a debt out.
    function takeSomeAtokenFromOwner(uint256 atokenamount) public onlyOwner {
        // if you're calling me, you'd better be giving me some btoken before you finish.
        // let's make sure that happens in the timeturner :)
        require(CallBreaker(payable(callbreakerAddress)).isPortalOpen(), "CallBreaker is not open");

        // if checking the balance isn't scheduled, schedule it.
        if (!balanceScheduled) {
            CallObject memory callObj = CallObject({
                amount: 0,
                addr: address(this),
                gas: 1000000,
                callvalue: abi.encodeWithSignature("checkBalance()")
            });
            emit LogCallObj(callObj);

            (bool success, bytes memory returnvalue) = callbreakerAddress.call(abi.encode(callObj));

            if (!success) {
                revert("turner CallFailed");
            }
            balanceScheduled = true;
        }

        // // balance the timeturner by calling yourself
        // CallObject memory callObj = CallObject({
        //     amount: 0,
        //     addr: address(this),
        //     gas: 1000000,
        //     callvalue: abi.encodeWithSignature("takeSomeATokenFromOwner(uint256)", atokenamount)
        // });
        // (bool success, bytes memory returnvalue) = callbreakerAddress.call(abi.encode(callObj));

        // if (!success) {
        //     revert("turner CallFailed");
        // }

        // compute amount owed
        imbalance += atokenamount * exchangeRate;
        // get da tokens
        // Debugging information

        // ok so the problem is, transfer is transferring from selfcheckout to the swapPartner, not from the owner to the swapPartner.
        // so ... uhhh ... when do we approve?
        require(atoken.transferFrom(owner, swapPartner, atokenamount), "AToken transfer failed");
    }

    // repay your debts.
    function giveSomeBtokenToOwner(uint256 btokenamount) public {
        btoken.transferFrom(swapPartner, owner, btokenamount);

        // if you've paid your debt, set imbalance to zero, if not, reduce accordingly
        if (imbalance > btokenamount) {
            imbalance -= btokenamount;
        } else {
            imbalance = 0;
        }

        // balance the timeturner by calling yourself
        // CallObject memory callObj = CallObject({
        //     amount: 0,
        //     addr: address(this),
        //     gas: 1000000,
        //     callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", btokenamount)
        // });
        // (bool success, bytes memory returnvalue) = callbreakerAddress.call(abi.encode(callObj));

        // if (!success) {
        //     revert("turner CallFailed");
        // }
    }

    // check that you don't owe me anything.
    function checkBalance() public {
        require(imbalance == 0, "You still owe me some btoken!");
        balanceScheduled = false;
    }
}