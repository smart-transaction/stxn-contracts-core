// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {SelfCheckout} from "test/examples/SelfCheckout.sol";
import {MyErc20} from "test/examples/MyErc20.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeploySelfCheckout is Script, BaseDeployer {
    address private _tokenA;
    address private _tokenB;
    address private _callBreaker;

    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the SelfCheckout contract.
    modifier computeCreate2(bytes32 salt) {
        _tokenA = address(new MyErc20("TokenA", "A"));
        _tokenB = address(new MyErc20("TokenB", "B"));
        _callBreaker = vm.envAddress("CALL_BREAKER_ADDRESS");

        _create2addrCounter = computeCreate2Address(
            salt,
            hashInitCode(type(SelfCheckout).creationCode, abi.encode(_ownerAddress, _tokenA, _tokenB, _callBreaker))
        );

        _;
    }

    /// @dev Helper to iterate over chains and select fork.
    /// @param deployForks The chains to deploy to.
    function createDeployMultichain(Chains[] memory deployForks) internal override computeCreate2(_counterSalt) {
        console2.log("SelfCheckout create2 address:", _create2addrCounter, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying SelfCheckout to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            chainDeploySmartedContract();

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Function to perform actual deployment.
    function chainDeploySmartedContract() private broadcast(_deployerPrivateKey) {
        SelfCheckout sc = new SelfCheckout{salt: _counterSalt}(_ownerAddress, _tokenA, _tokenB, _callBreaker);

        require(_create2addrCounter == address(sc), "Address mismatch SelfCheckout");

        console2.log("SelfCheckout deployed at address:", address(sc), "\n");
    }
}
