// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {BaseDeployer} from "../BaseDeployer.s.sol";
import {MockERC20Token} from "test/utils/MockERC20Token.sol";

/* solhint-disable no-console*/
import {console2} from "forge-std/console2.sol";

contract DeployMockToken is Script, BaseDeployer {
    /// @dev Compute the CREATE2 addresses for contracts (proxy, counter).
    /// @param salt The salt for the MockDai contract.
    modifier computeCreate2(bytes32 salt) {
        _create2addr =
            computeCreate2Address(salt, hashInitCode(type(MockERC20Token).creationCode, abi.encode("MyToken", "TOK")));

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
        console2.log("ERC20 Token create2 address:", _create2addr, "\n");

        for (uint256 i; i < deployForks.length;) {
            console2.log("Deploying ERC20 Token to chain: ", uint256(deployForks[i]), "\n");

            createSelectFork(deployForks[i]);

            _chainDeployDai();

            unchecked {
                ++i;
            }
        }
        return _create2addr;
    }

    /// @dev Function to perform actual deployment.
    function _chainDeployDai() private broadcast(_deployerPrivateKey) {
        address tokenAddress = address(new MockERC20Token{salt: _salt}("MyToken", "TOK"));

        require(_create2addr == tokenAddress, "Address mismatch ERC20 Token");

        console2.log("ERC20 Token deployed at address:", tokenAddress, "\n");
    }
}
