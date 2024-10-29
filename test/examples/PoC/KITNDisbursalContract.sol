// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract KITNDisbursalContract is AccessControl {
    // KITN token, initialized in the constructor
    IERC20 public immutable kitnToken;

    struct CoinsSpendResult {
        address receiver;
        uint amount;
        bool result;
    }

    event CoinsSpent(CoinsSpendResult[] results);

    // Constructor sets the deploying address as the default admin of the contract
    constructor(address _kitnAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(DISBURSER, _msgSender());
        
        kitnToken = IERC20(_kitnAddress);
    }

    // Function to check the contract's balance
    function getKitnBalance() public view returns (uint) {
        return kitnToken.balanceOf(address(this));
    }

    // Function to spend coins from allowance within the validity period
    function spendCoins(
        address[] calldata _receivers,
        uint[] calldata _amounts
    ) public onlyRole(DISBURSER) {
        // Transfer KITN tokens from this contract to the _receiver
        require(
            _receivers.length == _amounts.length,
            "A number of receivers must be equal to a number of amounts"
        );
        CoinsSpendResult[] memory results = new CoinsSpendResult[](
            _receivers.length
        );

        for (uint256 i = 0; i < _receivers.length; i++) {
            results[i].receiver = _receivers[i];
            results[i].amount = _amounts[i];
            results[i].result = kitnToken.transfer(_receivers[i], _amounts[i]);
        }

        emit CoinsSpent(results);
    }
}