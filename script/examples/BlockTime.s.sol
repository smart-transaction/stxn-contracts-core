
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {BlockTime} from "src/utilities/BlockTime.sol";
import {BlockTimeScheduler} from "test/examples/BlockTime/BlockTimeScheduler.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployBlockTime is Script, BaseDeployer {
    address private _callBreaker;
    address private _blockTime;
    address private _blockTimeScheduler;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the BlockTime contract.
    modifier computeCreate2(bytes32 salt) {
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        _blockTime =
            computeCreate2Address(salt, hashInitCode(type(BlockTime).creationCode, abi.encode()));
        _blockTimeScheduler = 
            computeCreate2Address(salt, hashInitCode(type(BlockTimeScheduler).creationCode, abi.encode(_callBreaker, _blockTime)));

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
        console2.log("BlockTime create2 address:", _blockTime, "\n");
        console2.log("BlockTimeScheduler create2 address:", _blockTimeScheduler, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying BlockTime and BlockTimeScheduler to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeployBlockTime();

            unchecked {
                ++i;
            }
        }
        return _blockTime;
    }

    /// @dev Function to perform actual deployment.
    function chainDeployBlockTime() private broadcast(_deployerPrivateKey) {
        address blockTime = address(new BlockTime{salt: _salt}());
        address blockTimeScheduler = address(new BlockTimeScheduler{salt: _salt}(_callBreaker, blockTime));

        require(_blockTime == blockTime, "Address mismatch BlockTime");
        require(_blockTimeScheduler == blockTimeScheduler, "Address mismatch BlockTimeScheduler");

        console2.log("BlockTime deployed at address:", blockTime, "\n");
        console2.log("BlockTimeScheduler deployed at address:", blockTimeScheduler, "\n");
    }
}
