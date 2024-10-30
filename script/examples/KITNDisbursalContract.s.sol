// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {KITNDisbursalContract} from "src/utilities/KITNDisbursalContract.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployKITNDisbursalContract is Script, BaseDeployer {
    address private _kitn;
    address private _kitnOwner;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the KITNDisbursalContract contract.
    modifier computeCreate2(bytes32 salt) {
        _kitn = vm.envAddress("KITN_ADDRESS");
        _kitnOwner = vm.envAddress("KITN_OWNER");

        _create2addr = computeCreate2Address(
            salt, hashInitCode(type(KITNDisbursalContract).creationCode, abi.encode(_kitn, _kitnOwner))
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
        console2.log("KITNDisbursalContract create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying KITNDisbursalContract to chain: ", uint256(deployForks[i]), "\n");

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
        address kitnDisbursalCt = address(new KITNDisbursalContract{salt: _salt}(_kitn, _kitnOwner));

        require(_create2addr == kitnDisbursalCt, "Address mismatch KITNDisbursalContract");

        console2.log("KITNDisbursalContract deployed at address:", kitnDisbursalCt, "\n");
    }
}
