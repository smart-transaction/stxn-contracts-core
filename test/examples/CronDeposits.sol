// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../../src/timetravel/CallBreaker.sol";

contract CronDeposits {
    address private _callbreakerAddress;
    IERC20 atoken;
    bool withdrawalScheduled;
    address withdrawer;

    error NotEmpty();

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(address callbreakerLocation, address _atoken) {
        _callbreakerAddress = callbreakerLocation;
        atoken = IERC20(_atoken);
    }

    function deposit(uint256 atokenamount) public {
        require(CallBreaker(payable(_callbreakerAddress)).isPortalOpen(), "CallBreaker is not open");

        // if checking the balance isn't scheduled, schedule it.
        if (!withdrawalScheduled) {
            CallObject memory callObj = CallObject({
                amount: 0,
                addr: address(this),
                gas: 1000000,
                callvalue: abi.encodeWithSignature("ensureFundless()")
            });

            CallObjectWithIndex memory callObjectWithIndex = CallObjectWithIndex({callObj: callObj, index: 3});

            (bool success,) = _callbreakerAddress.call(abi.encode(callObjectWithIndex));

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
