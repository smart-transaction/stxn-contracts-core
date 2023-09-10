// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./LaminatedProxy.sol";

contract Laminator {
    /// @dev Emitted when a new proxy contract is created.
    /// @param owner The owner of the newly created proxy contract.
    /// @param proxyAddress The address of the newly created proxy contract.
    event ProxyCreated(address indexed owner, address indexed proxyAddress);

    /// @dev Emitted when a function call is pushed to a proxy contract for deferred execution.
    /// @param proxyAddress The address of the proxy contract where the function call is pushed.
    /// @param callObj The CallObject containing the function call details.
    /// @param sequenceNumber The sequence number assigned to the deferred function call.
    event ProxyPushed(address indexed proxyAddress, CallObject callObj, uint256 sequenceNumber);

    /// @dev Emitted when a function call is executed immediately via a proxy contract.
    /// @param proxyAddress The address of the proxy contract where the function call is executed.
    /// @param callObj The CallObject containing the function call details.
    event ProxyExecuted(address indexed proxyAddress, CallObject callObj);

    /// @notice Gets the proxy address for the sender or creates a new one if it doesn't exist.
    /// @dev Computes the proxy address for the sender using `computeProxyAddress`. If a proxy doesn't
    ///      already exist, it will be created using the `create2` Ethereum opcode.
    ///      An event `ProxyCreated` is emitted if a new proxy is created.
    /// @return proxyAddress The address of the proxy contract for the sender.
    function getOrCreateProxy() public returns (address) {
        address proxyAddress = computeProxyAddress(msg.sender);

        // Check if the proxy contract already exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(proxyAddress)
        }

        if (codeSize == 0) {
            // Create a new proxy contract using create2
            bytes32 salt = keccak256(abi.encodePacked(msg.sender));
            bytes memory constructorArgs = abi.encode(msg.sender, address(this)); // Encode the constructor arguments
            bytes memory bytecode = abi.encodePacked(type(LaminatedProxy).creationCode, constructorArgs); // Append the constructor arguments to the bytecode

            assembly {
                proxyAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
            }

            // Emit an event for the creation of a new proxy contract
            emit ProxyCreated(msg.sender, proxyAddress);
        }

        return proxyAddress;
    }

    /// @notice Computes the deterministic address for a proxy contract for the given owner.
    /// @dev Uses the CREATE2 opcode to calculate the address for the proxy contract.
    ///      The proxy address is generated deterministically based on the owner's address,
    ///      the bytecode, and the salt.
    /// @param owner The address for which to compute the proxy address.
    /// @return The computed proxy address.
    function computeProxyAddress(address owner) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(owner));
        bytes memory constructorArgs = abi.encode(owner, address(this)); // Encode the constructor arguments
        bytes memory bytecode = abi.encodePacked(type(LaminatedProxy).creationCode, constructorArgs); // Append the constructor arguments to the bytecode

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        return address(uint160(uint256(hash)));
    }

    /// @notice Delegatecalls the `push` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided calldata and delegatecalls it into the `push` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param cData The calldata to be pushed.
    /// @param delay The delay for when the call can be executed.
    /// @return sequenceNumber The sequence number of the deferred function call.
    function pushToProxy(bytes calldata cData, uint256 delay) external returns (uint256 sequenceNumber) {
        address proxyAddress = getOrCreateProxy();

        bytes memory payload = abi.encodeWithSignature("push(bytes, uint256)", cData, delay);
        (bool success, bytes memory returnData) = proxyAddress.delegatecall(payload);
        require(success, "Laminator: Delegatecall to push failed");
        sequenceNumber = abi.decode(returnData, (uint256));

        CallObject memory callObj = abi.decode(cData, (CallObject));
        emit ProxyPushed(proxyAddress, callObj, sequenceNumber);
    }

    /// @notice Delegatecalls the `execute` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided calldata and delegatecalls it into the `execute` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param cData The calldata to be executed.
    function executeInProxy(bytes calldata cData) external returns (bytes memory){
        address proxyAddress = getOrCreateProxy();

        bytes memory payload = abi.encodeWithSignature("execute(bytes)", cData);
        (bool success, bytes memory data) = proxyAddress.delegatecall(payload);
        require(success, "Laminator: Delegatecall to execute failed");

        CallObject memory callObj = abi.decode(cData, (CallObject));
        emit ProxyExecuted(proxyAddress, callObj);

        return data;
    }
}
