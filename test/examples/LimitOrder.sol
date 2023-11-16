// TODO
// vlad didn't ask me to write this, but i think it'll be illustrative
// use the timeturner to enforce slippage on a uniswap trade
// set slippage really high, let yourself slip, then use the timeturner to revert the trade if the price was above some number.
// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../../src/TimeTypes.sol";
import "../../src/timetravel/CallBreaker.sol";

contract LimitOrder {
    address public owner;
    address public callbreakerAddress;

    IERC20 public atoken;
    IERC20 public btoken;

    // hardcoded slippage
    uint256 public slippage = 50;

    // your debt to the protocol denominated in btoken
    uint256 public imbalance = 0;

    // tracks if we've called checkBalance yet. if not it needs to be.
    bool public balanceScheduled = false;

    // when a debt is taken out of the protocol, it goes here. should be called right before executing a pull...
    address public swapPartner;

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
    // exchangeRate is the number of btoken you get for 1 atoken.
    function takeSomeAtokenFromOwner(uint256 atokenamount, uint256 exchangeRate) public onlyOwner {
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

            (bool success,) = callbreakerAddress.call(abi.encode(callObj));

            if (!success) {
                revert("turner CallFailed");
            }
            balanceScheduled = true;
        }

        // compute amount owed
        imbalance += atokenamount * exchangeRate;
        // get da tokens
        // Debugging information

        require(atoken.transferFrom(owner, swapPartner, atokenamount), "AToken transfer failed");
    }

    // repay your debts.
    function giveSomeBtokenToOwner(uint256 btokenamount) public {
        btoken.transferFrom(swapPartner, owner, btokenamount);

        if (imbalance > btokenamount) {
            imbalance -= btokenamount;
        } else {
            imbalance = 0;
        }
    }

    // check that you don't owe me anything.
    function checkBalance() public {
        require(imbalance == 0, "You still owe me some btoken!");
        balanceScheduled = false;
    }
}
