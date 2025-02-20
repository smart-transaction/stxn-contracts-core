// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {AshMintScheduler} from "src/schedulers/AshMintScheduler.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployAshMintScheduler is Script, BaseDeployer {
    address private _callBreaker;
    address private _ashBI;
    address private _ashB;
    address private _ashBIS;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the AshMintScheduler contract.
    modifier computeCreate2(bytes32 salt) {
        _ashBI = vm.envAddress("ASH_BI");
        _ashB = vm.envAddress("ASH_B");
        _ashBIS = vm.envAddress("ASH_BIS");
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        _create2addr = computeCreate2Address(
            salt,
            hashInitCode(
                type(AshMintScheduler).creationCode, abi.encode(_callBreaker, _ownerAddress, _ashBI, _ashB, _ashBIS, _ownerAddress)
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
        console2.log("AshMintScheduler create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying AshMintScheduler to chain: ", uint256(deployForks[i]), "\n");

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
        address _ashMintScheduler =
            address(new AshMintScheduler{salt: _salt}(_callBreaker, _ownerAddress, _ashBI, _ashB, _ashBIS, _ownerAddress));

        require(_create2addr == _ashMintScheduler, "Address mismatch AshMintScheduler");

        console2.log("AshMintScheduler deployed at address:", _ashMintScheduler, "\n");
    }
}
