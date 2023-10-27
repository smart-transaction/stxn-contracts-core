// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../../src/timetravel/CallBreaker.sol";

contract CronDeposits {
    address private _callbreakerAddress;
    IERC20 atoken;
    bool withdrawalScheduled;
    address withdrawer;

    // we can make sure that we have end to end control over the execution of the transaction by
    // 1. making sure that the callbreaker is open
    // could we check that the laminatorpull was the second call out of the callbreaker...?
    // no, you can do some shit right before in a contract
    // check that something is EOA perhaps by checking that no code is deployed
    // what if something creates and selfdestructs before you run
    // CAN'T do that- selfdestruct halts execution
    // you 

    // ok. kick the callbreaker off with an EOA wallet check
    // this means verify is the first damn call
    // also, add an index to the timeturner. you have to ensure you're in the right order- there will be indices "counting from the top" of the order things showed up in verify
    // pull: first, you go straight into the "cleanup" code. you have no choice
    // ok but what if you wrap INSIDE verify? how do you prevent this? push can clean itself up... the only way to do this is to ensure you're at the top of the verify call
    //
    //
    //
    //


    error NotEmpty();

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(address callbreakerLocation, address _atoken) {
        _callbreakerAddress = callbreakerLocation;
        atoken = IERC20(_atoken);
    }

    function deposit(uint256 atokenamount) public {
        // if you're calling me, you'd better be pulling my funds out before you finish.
        // let's make sure that happens in the timeturner :)
        // ... we don't check who pulls out the funds... that's the fun part ;)
        require(CallBreaker(payable(_callbreakerAddress)).isPortalOpen(), "CallBreaker is not open");

        // if checking the balance isn't scheduled, schedule it.
        if (!withdrawalScheduled) {
            CallObject memory callObj = CallObject({
                amount: 0,
                addr: address(this),
                gas: 1000000,
                callvalue: abi.encodeWithSignature("ensureFundless()")
            });

            (bool success, bytes memory returnValue) = _callbreakerAddress.call(abi.encode(callObj));

            if (!success) {
                revert("turner CallFailed");
            }
            withdrawalScheduled = true;
        }

        // get da tokens
        // Debugging information
        emit Transfer(msg.sender, address(this), atokenamount);
        require(atoken.transferFrom(msg.sender, address(this), atokenamount), "AToken transfer failed");
    }

    function withdraw(uint256 tokenAmount) public {
        emit Transfer(address(this), withdrawer, tokenAmount);
        atoken.transfer(withdrawer, tokenAmount);
    }

    function setWithdrawer(address exploiter) public {
        withdrawer = exploiter;
    }

    function ensureFundless() public {
        if (atoken.balanceOf(address(this)) != 0) {
            revert NotEmpty();
        }
        withdrawalScheduled = false;
    }

    // Takes in arbitrary bytes at MEV Time
    function _isVulnerable(bytes memory input) internal pure returns (bool) {
        bytes memory vulnString = "vulnerable";
        return keccak256(vulnString) == keccak256(input);
    }
}

contract Oracle {
    constructor() {}

    event LogBytesReceived(bytes data);
    event LogFeeReceived(uint256 fee);

    // Returns 'some arbitrary amount' to withdraw
    function returnArbitraryData(uint256 fee, bytes memory seed) public returns (bytes memory) {
        // Oracle takes fee, returns some arbitrary data
        emit LogFeeReceived(fee);
        // Arbitrary data processing happens here
        emit LogBytesReceived(seed);
        return seed;
    }
}
