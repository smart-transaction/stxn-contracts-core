// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {CronCounter} from "test/examples/CronCounter.sol";
import {MyErc20} from "test/examples/MyErc20.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployCronCounter is Script, BaseDeployer {
    address private _callBreaker;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the CronCounter contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        _create2addr =
            computeCreate2Address(salt, hashInitCode(type(CronCounter).creationCode, abi.encode(_callBreaker)));

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
        console2.log("CronCounter create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying CronCounter to chain: ", uint256(deployForks[i]), "\n");

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
        address cronTwoCounter = address(new CronCounter{salt: _salt}(_callBreaker));

        require(_create2addr == cronTwoCounter, "Address mismatch CronCounter");

        console2.log("CronCounter deployed at address:", cronTwoCounter, "\n");
    }
}
