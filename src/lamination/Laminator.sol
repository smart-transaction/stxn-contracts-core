// SPDX-License-Identifier: MIT
pragma solidity ^=0.8.20;

import "./LaminatedProxy.sol";

contract Laminator {
    // Event to log the creation of a new proxy contract
    event ProxyCreated(address indexed owner, address indexed proxyAddress);
    event ProxyPushed(address indexed proxyAddress, CallObject callObj, uint256 sequenceNumber);
    event ProxyExecuted(address indexed proxyAddress, CallObject callObj);

    // Function to compute the proxy contract address for an owner
    function computeProxyAddress(address owner) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(owner));
        bytes memory constructorArgs = abi.encode(owner); // Encode the constructor arguments
        bytes memory bytecode = abi.encodePacked(type(LaminatedProxy).creationCode, constructorArgs); // Append the constructor arguments to the bytecode

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        return address(uint160(uint256(hash)));
    }

    // Function to get or create a proxy contract for the sender
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
            bytes memory constructorArgs = abi.encode(address(this), msg.sender); // Encode the constructor arguments
            bytes memory bytecode = abi.encodePacked(type(LaminatedProxy).creationCode, constructorArgs); // Append the constructor arguments to the bytecode

            assembly {
                proxyAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
            }

            // Emit an event for the creation of a new proxy contract
            emit ProxyCreated(msg.sender, proxyAddress);
        }

        return proxyAddress;
    }

    // Function to delegatecall 'push' into the LaminatedProxy
    // TODO decisions about encoding and decoding!
    function pushToProxy(bytes calldata cData, uint256 delay) public returns (uint256 sequenceNumber) {
        address proxyAddress = getOrCreateProxy();

        bytes memory payload = abi.encodeWithSignature("push(bytes, uint256)", cData, delay);

        (bool success, bytes memory returnData) = proxyAddress.delegatecall(payload);
        require(success, "Laminator: Delegatecall to push failed");

        sequenceNumber = abi.decode(returnData, (uint256));
        CallObject memory callObj = abi.decode(cData, (CallObject));
        emit ProxyPushed(proxyAddress, callObj, sequenceNumber);
    }

    // Function to delegatecall 'push' into the LaminatedProxy default delay is 1
    function pushToProxy(bytes calldata cData) public returns (uint256 sequenceNumber) {
        return pushToProxy(cData, 1);
    }

    // Function to delegatecall 'execute' into the LaminatedProxy
    // TODO decisions about encoding and decoding!
    function executeInProxy(bytes calldata cData) public {
        address proxyAddress = getOrCreateProxy();
        bytes memory payload = abi.encodeWithSignature("execute(bytes)", cData);

        (bool success,) = proxyAddress.delegatecall(payload);
        require(success, "Laminator: Delegatecall to execute failed");
        CallObject memory callObj = abi.decode(cData, (CallObject));
        emit ProxyExecuted(proxyAddress, callObj);
    }
}
