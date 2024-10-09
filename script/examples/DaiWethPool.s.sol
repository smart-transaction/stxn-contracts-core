// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {MockDaiWethPool} from "test/examples/DeFi/MockDaiWethPool.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployMockDaiWethPool is Script, BaseDeployer {
    address private _callBreaker;
    address private _weth;
    address private _dai;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the MockDaiWethPool contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");
        _dai = vm.envAddress("DAI_ADDRESS");
        _weth = vm.envAddress("WETH_ADDRESS");

        _create2addr =
            computeCreate2Address(salt, hashInitCode(type(MockDaiWethPool).creationCode, abi.encode(_callBreaker, _dai, _weth)));

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
        console2.log("MockDaiWethPool create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying MockDaiWethPool to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            _chainDeployDaiWethPool();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function _chainDeployDaiWethPool() private broadcast(_deployerPrivateKey) {
        address mockDaiWethPool = address(new MockDaiWethPool{salt: _salt}(_callBreaker, _dai, _weth));

        require(_create2addr == mockDaiWethPool, "Address mismatch MockDaiWethPool");

        console2.log("MockDaiWethPool deployed at address:", mockDaiWethPool, "\n");
    }
}
