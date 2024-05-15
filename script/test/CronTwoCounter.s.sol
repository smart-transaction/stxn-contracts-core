// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {CronTwoCounter} from "test/examples/CronTwoCounter.sol";
import {MyErc20} from "test/examples/MyErc20.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployCronTwoCounter is Script, BaseDeployer {
    address private _callBreaker;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the CronTwoCounter contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        _create2addrCounter = computeCreate2Address(
            salt,
            hashInitCode(type(CronTwoCounter).creationCode, abi.encode(_callBreaker))
        );

        _;
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function createDeployMultichain(Chains[] memory deployForks) internal override computeCreate2(_counterSalt) {
        console2.log("CronTwoCounter create2 address:", _create2addrCounter, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying CronTwoCounter to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeploySmartedContract();

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Function to perform actual deployment.
    function chainDeploySmartedContract() private broadcast(_deployerPrivateKey) {
        address cronTwoCounter = address(new CronTwoCounter{salt: _counterSalt}(_callBreaker));

        require(_create2addrCounter == cronTwoCounter, "Address mismatch CronTwoCounter");

        console2.log("CronTwoCounter deployed at address:", cronTwoCounter, "\n");
    }
}
