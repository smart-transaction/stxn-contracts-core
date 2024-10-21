// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {MockFlashLoan} from "test/examples/DeFi/MockFlashLoan.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployMockFlashLoan is Script, BaseDeployer {
    address private _weth;
    address private _dai;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the MockFlashLoan contract.
    modifier computeCreate2(bytes32 salt) {
        _dai = vm.envAddress("DAI_ADDRESS");
        _weth = vm.envAddress("WETH_ADDRESS");

        _create2addr =
            computeCreate2Address(salt, hashInitCode(type(MockFlashLoan).creationCode, abi.encode(_dai, _weth)));

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
        console2.log("MockFlashLoan create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying MockFlashLoan to chain: ", uint256(deployForks[i]), "\n");

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
        address mockFlashLoan = address(new MockFlashLoan{salt: _salt}(_dai, _weth));

        require(_create2addr == mockFlashLoan, "Address mismatch MockFlashLoan");

        console2.log("MockFlashLoan deployed at address:", mockFlashLoan, "\n");
    }
}
