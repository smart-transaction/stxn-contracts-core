// on calling the transfer function
// you need to ensure that in the future of this transaction, they transfer the tokens back to the contract and end up being at zero.
// ok. here we go!

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";
import "./TimeTurner.sol";

abstract contract FlashPill is IERC20 {

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    // tracks nonzero balances
    address[] private _nonzeroBalances;

    // 1-based indexing into the balance tracker array. 0 represents non-existence.
    mapping(address => uint256) private _indexOf;

    struct AddressTuple {
        address a;
        address b;
        bool isValue;
    }

    // list all allowances so we can zero them back out after (they're allowed to be nonzero at the end, but they get reset)
    bytes32[] private _allowanceList;
    mapping(bytes32 => AddressTuple) private _allowanceExists;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    address _timeturnerAddress;

    bool _moneyWasReturnedScheduled = false;

    constructor(address timeturnerLocation) {
        _timeturnerAddress = timeturnerLocation;
        _name = "TinaFromFlashBotsCoin";
        _symbol = "HITINA";
    }

    function getHashOfAllowancePair(address owner, address spender) public pure returns (bytes32) {
        return keccak256(abi.encode(owner, spender));
    }

    function moneyWasReturnedCheck() public {
        // only the time turner can call this function.
        require(msg.sender == _timeturnerAddress, "only the time turner can call this function");

        // and it should have been scheduled! i think this is just a sanity check. i hope...
        require(_moneyWasReturnedScheduled, "moneyWasReturned was not scheduled");

        // ensure the totalSupply was reset to zero.
        require(_totalSupply == 0, "totalSupply was not reset to zero");

        // reverts if everybody's value isn't zero.
        for (uint256 i = 0; i < _nonzeroBalances.length; i++) {
            address nonzeroBalanceAddress = _nonzeroBalances[i];
            uint256 nonzeroBalance = _balances[nonzeroBalanceAddress];
            require(nonzeroBalance == 0, "there was a nonzero balance. haram!");
        }

        // and... reset all the variables for the next user if we succeeded! :)
        _moneyWasReturnedScheduled = false;

        // BALANCES SHOULD ALL BE ZERO
        // not going to check, but it should be if our code is right. whoever fuzzes this... that's on you.
        
        // clear indexOf
        for (uint256 i = 0; i < _nonzeroBalances.length; i++) {
            address nonzeroBalanceAddress = _nonzeroBalances[i];
            _indexOf[nonzeroBalanceAddress] = 0;
        }
        delete _nonzeroBalances;

        // totalSupply is already zero (we already checked)

        // clear allowances
        for (uint256 i = 0; i < _allowanceList.length; i++) {
            bytes32 allowancePair = _allowanceList[i];
            AddressTuple memory allowancePairTuple = _allowanceExists[allowancePair];
            if (allowancePairTuple.isValue) {
                delete _allowances[allowancePairTuple.a][allowancePairTuple.b];
            }
        }
    }

    function scheduleMoneyReturnCheck() public {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("moneyWasReturnedCheck()")
        });

        (bool success, bytes memory returnvalue) = _timeturnerAddress.call(abi.encode(callObjs));

        if (!success) {
            revert("turner CallFailed");
        }

        _moneyWasReturnedScheduled = true;
    }

    function removeNonZeroBalanceMarker(address x) public {
        uint256 index = _indexOf[x];

        require(index > 0);

        // move the last item into the index being vacated
        address lastValue = _nonzeroBalances[_nonzeroBalances.length - 1];
        _nonzeroBalances[index - 1] = lastValue;  // adjust for 1-based indexing
        _indexOf[lastValue] = index;

        _nonzeroBalances.pop();

        _indexOf[x] = 0;
    }

    function addNonZeroBalanceMarker(address x) public {
        if (_indexOf[x] == 0) {
            _nonzeroBalances.push(x);
            _indexOf[x] = _nonzeroBalances.length;
        }
    }

    function transfer(address to, uint256 value) public returns (bool) {
        if (!_moneyWasReturnedScheduled) {
            scheduleMoneyReturnCheck();
        }

        address owner = msg.sender;
        bool ownerWasZero = _balances[owner] == 0;
        bool toWasZero = _balances[to] == 0;

        // yeehaw the overflow and balance checks, we literally do not care at all.
        // future us will figure it out ;)
        _balances[owner] -= value;
        _balances[to] += value;

        bool ownerIsZeroNow = _balances[owner] == 0;
        bool toIsZeroNow = _balances[to] == 0;

        // did a value become nonzero? if so, add it to nonzero balances
        if (ownerWasZero && !ownerIsZeroNow) {
            addNonZeroBalanceMarker(owner);
        }
        if (toWasZero && !toIsZeroNow) {
            addNonZeroBalanceMarker(to);
        }

        // did a value that was nonzero become zero? if so, remove it from nonzero balances
        if (!ownerWasZero && ownerIsZeroNow) {
            removeNonZeroBalanceMarker(owner);
        }
        if (!toWasZero && toIsZeroNow) {
            removeNonZeroBalanceMarker(to);
        }

        emit Transfer(owner, to, value);

        return true;
    }

    function setTotalSupply(uint256 value) public {
        if (!_moneyWasReturnedScheduled) {
            scheduleMoneyReturnCheck();
        }
        _totalSupply = value;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) external returns (bool) {
        if (!_moneyWasReturnedScheduled) {
            scheduleMoneyReturnCheck();
        }

        address owner = msg.sender;
        _allowances[owner][spender] = value;


        bytes32 hashOfAllowancePair = getHashOfAllowancePair(owner, spender);
        if (_allowanceExists[hashOfAllowancePair].isValue) {
            _allowanceList.push(hashOfAllowancePair);
            _allowanceExists[hashOfAllowancePair] = AddressTuple({a: owner, b: spender, isValue: true});
        }

        emit Approval(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (!_moneyWasReturnedScheduled) {
            scheduleMoneyReturnCheck();
        }

        bool fromWasZero = _balances[from] == 0;
        bool toWasZero = _balances[to] == 0;

        // yeehaw the overflow and balance checks, we literally do not care at all.
        _balances[from] -= value;
        _balances[to] += value;

        bool fromIsZeroNow = _balances[from] == 0;
        bool toIsZeroNow = _balances[to] == 0;

        // did a value become nonzero? if so, add it to nonzero balances
        if (fromWasZero && !fromIsZeroNow) {
            addNonZeroBalanceMarker(from);
        }
        if (toWasZero && !toIsZeroNow) {
            addNonZeroBalanceMarker(to);
        }

        // did a value that was nonzero become zero? if so, remove it from nonzero balances
        if (!fromWasZero && fromIsZeroNow) {
            removeNonZeroBalanceMarker(from);
        }
        if (!toWasZero && toIsZeroNow) {
            removeNonZeroBalanceMarker(to);
        }

        emit Transfer(from, to, value);

        return true;
    }
}