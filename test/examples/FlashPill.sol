// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "openzeppelin/token/ERC20/IERC20.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../src/timetravel/SmarterContract.sol";

contract FlashPill is IERC20, SmarterContract {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    address[] private _nonzeroBalances;

    mapping(address => uint256) private _indexOf;

    struct AddressTuple {
        address a;
        address b;
        bool isValue;
    }

    bytes32[] private _allowanceList;
    mapping(bytes32 => AddressTuple) private _allowanceExists;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    address _callbreakerAddress;

    bool _moneyWasReturnedScheduled = false;

    constructor(address callbreakerLocation) SmarterContract(callbreakerLocation) {
        _callbreakerAddress = callbreakerLocation;
        _name = "TOKEN";
        _symbol = "TKN";
    }

    function getHashOfAllowancePair(address owner, address spender) public pure returns (bytes32) {
        return keccak256(abi.encode(owner, spender));
    }

    function moneyWasReturnedCheck() public {
        // TODO: consider whether or not there need to be any checks on who the caller is?
        require(_moneyWasReturnedScheduled, "moneyWasReturned was not scheduled");

        // ensure the totalSupply was reset to zero.
        require(_totalSupply == 0, "totalSupply was not reset to zero");

        // reverts if everybody's value isn't zero.
        for (uint256 i = 0; i < _nonzeroBalances.length; i++) {
            address nonzeroBalanceAddress = _nonzeroBalances[i];
            uint256 nonzeroBalance = _balances[nonzeroBalanceAddress];
            require(nonzeroBalance == 0, "there was a nonzero balance. haram!");
        }

        // Reset all the variables for the next user on success
        _moneyWasReturnedScheduled = false;

        for (uint256 i = 0; i < _nonzeroBalances.length; i++) {
            address nonzeroBalanceAddress = _nonzeroBalances[i];
            _indexOf[nonzeroBalanceAddress] = 0;
        }
        delete _nonzeroBalances;

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

        assertFutureCallTo(callObjs[0]);

        _moneyWasReturnedScheduled = true;
    }

    function removeNonZeroBalanceMarker(address x) public {
        uint256 index = _indexOf[x];

        require(index > 0);

        // move the last item into the index being vacated
        address lastValue = _nonzeroBalances[_nonzeroBalances.length - 1];
        _nonzeroBalances[index - 1] = lastValue; // adjust for 1-based indexing
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

        _balances[owner] -= value;
        _balances[to] += value;

        bool ownerIsZeroNow = _balances[owner] == 0;
        bool toIsZeroNow = _balances[to] == 0;

        // If a value becomes nonzero add it to the nonzero balances
        if (ownerWasZero && !ownerIsZeroNow) {
            addNonZeroBalanceMarker(owner);
        }
        if (toWasZero && !toIsZeroNow) {
            addNonZeroBalanceMarker(to);
        }

        // If a nonzero value becomes zero remove it from the nonzero balances
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

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
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

        _balances[from] -= value;
        _balances[to] += value;

        bool fromIsZeroNow = _balances[from] == 0;
        bool toIsZeroNow = _balances[to] == 0;

        if (fromWasZero && !fromIsZeroNow) {
            addNonZeroBalanceMarker(from);
        }
        if (toWasZero && !toIsZeroNow) {
            addNonZeroBalanceMarker(to);
        }

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
