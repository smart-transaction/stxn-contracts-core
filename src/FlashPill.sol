// on calling the transfer function
// you need to ensure that in the future of this transaction, they transfer the tokens back to the contract and end up being at zero.
// ok. here we go!

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin/token/ERC20/IERC20.sol";
import "./TimeTurner.sol";

contract FlashPill is IERC20 {

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    // tracks nonzero balances
    address[] private _nonzeroBalances;
    // 1-based indexing into the array. 0 represents non-existence.
    mapping(address => uint256) private _indexOf;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    address timeturner_address;

    bool moneyWasReturnedScheduled = false;

    constructor(address timeturner_location) {
        timeturner_address = timeturner_location;
        _name = "TinaFromFlashBotsCoin";
        _symbol = "HITINA";
    }

    function moneyWasReturnedCheck() {
        // only the time turner can call this function.
        require(msg.sender == timeturner_address, "only the time turner can call this function");

        // and it should have been scheduled! i think this is just a sanity check. i hope...
        require(moneyWasReturnedScheduled, "moneyWasReturned was not scheduled");

        // ensure the totalSupply was reset to zero.
        require(_totalSupply == 0, "totalSupply was not reset to zero");

        // reverts if everybody's value isn't zero.
        for (uint256 i = 0; i < _nonzeroBalances.length; i++) {
            address nonzeroBalanceAddress = _nonzeroBalances[i];
            uint256 nonzeroBalance = _balances[nonzeroBalanceAddress];
            require(nonzeroBalance == 0, "there was a nonzero balance. haram!");
        }

        // and... reset all the variables for the next transaction.
        moneyWasReturnedScheduled = false;
        delete _indexOf;
        delete _nonzeroBalances;
        delete _balances;
        delete _allowances;
    }

    function scheduleMoneyReturnCheck() {
        CallObject[] memory callObjs = new CallObject[](1);
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("moneyWasReturnedCheck()")
        });

        (bool success, bytes memory returnvalue) = timeturner_address.call(abi.encode(callObjs));

        if (!success) {
            revert("turner CallFailed");
        }

        moneyWasReturnedScheduled = true;
    }

    function remove_nonzero_balance_marker(address x) {
        uint256 index = indexOf[x];

        require(index > 0);

        // move the last item into the index being vacated
        bytes32 lastValue = items[items.length - 1];
        items[index - 1] = lastValue;  // adjust for 1-based indexing
        indexOf[lastValue] = index;

        items.length -= 1;
        indexOf[x] = 0;
    }

    function add_nonzero_balance_marker(address x) {
        if (indexOf[x] == 0) {
            items.push(x);
            indexOf[x] = items.length;
        }
    }

    function transfer(address to, uint256 value) {
        if (!moneyWasReturnedScheduled) {
            scheduleMoneyReturnCheck();
        }

        address owner = _msgSender();
        bool owner_was_zero = _balances[owner] == 0;
        bool to_was_zero = _balances[to] == 0;

        // yeehaw the overflow and balance checks, we literally do not care at all.
        _balances[owner] -= value;
        _balances[to] += value;

        bool owner_is_zero_now = _balances[owner] == 0;
        bool to_is_zero_now = _balances[to] == 0;

        // did a value become nonzero? if so, add it to nonzero balances
        if (owner_was_zero && !owner_is_zero_now) {
            add_nonzero_balance_marker(owner);
        }
        if (to_was_zero && !to_is_zero_now) {
            add_nonzero_balance_marker(to);
        }

        // did a value that was nonzero become zero? if so, remove it from nonzero balances
        if (!owner_was_zero && owner_is_zero_now) {
            remove_nonzero_balance_marker(owner);
        }
        if (!to_was_zero && to_is_zero_now) {
            remove_nonzero_balance_marker(to);
        }

        emit Transfer(owner, to, value);

        return true;
    }

    function setTotalSupply(uint256 value) {
        if (!moneyWasReturnedScheduled) {
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
        if (!moneyWasReturnedScheduled) {
            scheduleMoneyReturnCheck();
        }
        
        address owner = _msgSender();
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (!moneyWasReturnedScheduled) {
            scheduleMoneyReturnCheck();
        }

        address spender = _msgSender();
        bool from_was_zero = _balances[from] == 0;
        bool to_was_zero = _balances[to] == 0;

        // yeehaw the overflow and balance checks, we literally do not care at all.
        _balances[from] -= value;
        _balances[to] += value;

        bool from_is_zero_now = _balances[from] == 0;
        bool to_is_zero_now = _balances[to] == 0;

        // did a value become nonzero? if so, add it to nonzero balances
        if (from_was_zero && !from_is_zero_now) {
            add_nonzero_balance_marker(from);
        }
        if (to_was_zero && !to_is_zero_now) {
            add_nonzero_balance_marker(to);
        }

        // did a value that was nonzero become zero? if so, remove it from nonzero balances
        if (!from_was_zero && from_is_zero_now) {
            remove_nonzero_balance_marker(from);
        }
        if (!to_was_zero && to_is_zero_now) {
            remove_nonzero_balance_marker(to);
        }

        emit Transfer(from, to, value);

        return true;
    }
}