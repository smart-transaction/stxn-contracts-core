// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {FlashLiquidity} from "test/examples/DeFi/FlashLiquidity.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployFlashLiquidity is Script, BaseDeployer {
    address private _callBreaker;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the FlashLiquidity contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        _create2addr = computeCreate2Address(
            salt, hashInitCode(type(FlashLiquidity).creationCode, abi.encode(_callBreaker, _ownerAddress))
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
        console2.log("FlashLiquidity create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying FlashLiquidity to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeploySmartedContract();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function chainDeploySmartedContract() private broadcast(_deployerPrivateKey) {
        address flashLiquidity = address(new FlashLiquidity{salt: _salt}(_callBreaker, _ownerAddress));

        require(_create2addr == flashLiquidity, "Address mismatch FlashLiquidity");

        console2.log("FlashLiquidity deployed at address:", flashLiquidity, "\n");
    }
}
