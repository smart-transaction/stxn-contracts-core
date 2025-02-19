// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {KITNDisburmentScheduler} from "src/schedulers/KITNDisburmentScheduler.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployKITNDisburmentScheduler is Script, BaseDeployer {
    address private _callBreaker;
    address private _kitnDisbursalCtr;
    address private _kitnOwner;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the KITNDisburmentScheduler contract.
    modifier computeCreate2(bytes32 salt) {
        _kitnDisbursalCtr = vm.envAddress("KITN_DISBURSAL_ADDRESS");
        _kitnOwner = vm.envAddress("KITN_OWNER");
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        _create2addr = computeCreate2Address(
            salt,
            hashInitCode(
                type(KITNDisburmentScheduler).creationCode, abi.encode(_callBreaker, _kitnDisbursalCtr, _kitnOwner)
            )
        );

        _;
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    /// @return address of the deployed contract
    function createDeployMultichain(Chains[] memory deployForks)
        internal
        override
        computeCreate2(_salt)
        returns (address)
    {
        console2.log("KITNDisburmentScheduler create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying KITNDisburmentScheduler to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            _chainDeployFlashLoan();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function _chainDeployFlashLoan() private broadcast(_deployerPrivateKey) {
        address kitnDisbursalCt =
            address(new KITNDisburmentScheduler{salt: _salt}(_callBreaker, _kitnDisbursalCtr, _kitnOwner));

        require(_create2addr == kitnDisbursalCt, "Address mismatch KITNDisburmentScheduler");

        console2.log("KITNDisburmentScheduler deployed at address:", kitnDisbursalCt, "\n");
    }
}
