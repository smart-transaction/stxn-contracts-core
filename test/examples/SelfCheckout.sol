// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../../src/TimeTypes.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../src/timetravel/SmarterContract.sol";

contract SelfCheckout is SmarterContract {
    address owner;
    address callbreakerAddress;

    IERC20 atoken;
    IERC20 btoken;

    // hardcoded exchange rate (btokens per atoken)
    uint256 exchangeRate = 2;

    // your debt to the protocol denominated in btoken
    uint256 imbalance = 0;

    // tracks if we've called checkBalance yet. if not it needs to be.
    bool balanceScheduled = false;

    event DebugAddress(string message, address value);
    event DebugInfo(string message, string value);
    event DebugUint(string message, uint256 value);

    constructor(address _owner, address _atoken, address _btoken, address _callbreakerAddress)
        SmarterContract(_callbreakerAddress)
    {
        owner = _owner;

        atoken = IERC20(_atoken);
        btoken = IERC20(_btoken);

        callbreakerAddress = _callbreakerAddress;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Proxy: Not the owner");
        _;
    }

    function getAtoken() public view returns (address) {
        return address(atoken);
    }

    function getBtoken() public view returns (address) {
        return address(btoken);
    }

    function getExchangeRate() public view returns (uint256) {
        return exchangeRate;
    }

    function getCallBreaker() public view returns (address) {
        return callbreakerAddress;
    }

    function getSwapPartner() public view returns (address) {
        bytes32 swapPartnerKey = keccak256(abi.encodePacked("swapPartner"));
        bytes memory swapPartnerBytes =
            CallBreaker(payable(callbreakerAddress)).fetchFromAssociatedDataStore(swapPartnerKey);
        return abi.decode(swapPartnerBytes, (address));
    }

    event LogCallObj(CallObject callObj);

    function takeSomeAtokenFromOwner(uint256 atokenamount) public onlyOwner {
        require(CallBreaker(payable(callbreakerAddress)).isPortalOpen(), "CallBreaker is not open");

        if (!balanceScheduled) {
            CallObject memory callObj = CallObject({
                amount: 0,
                addr: address(this),
                gas: 1000000,
                callvalue: abi.encodeWithSignature("checkBalance()")
            });
            emit LogCallObj(callObj);
            assertFutureCallTo(callObj);

            balanceScheduled = true;
        }

        imbalance += atokenamount * exchangeRate;
        require(atoken.transferFrom(owner, getSwapPartner(), atokenamount), "AToken transfer failed");
    }

    function giveSomeBtokenToOwner(uint256 btokenamount) public {
        btoken.transferFrom(getSwapPartner(), owner, btokenamount);

        if (imbalance > btokenamount) {
            imbalance -= btokenamount;
        } else {
            imbalance = 0;
        }
    }

    function checkBalance() public {
        require(imbalance == 0, "You still owe me some btoken!");
        balanceScheduled = false;
    }
}
