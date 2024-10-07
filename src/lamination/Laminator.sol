// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.2 <0.9.0;

import "./LaminatedProxy.sol";
import "../interfaces/ICallBreaker.sol";

contract Laminator is ILaminator {
    ICallBreaker public callBreaker;

    /// @notice The address passed was a zero address
    error AddressZero();

    /// @dev Emitted when a new proxy contract is created.
    /// @param owner The owner of the newly created proxy contract.
    /// @param proxyAddress The address of the newly created proxy contract.
    event ProxyCreated(address indexed owner, address indexed proxyAddress);

    /// @dev Emitted when a function call is pushed to a proxy contract for deferred execution.
    /// @param proxyAddress The address of the proxy contract where the function call is pushed.
    /// @param callObjs The CallObject containing the function call details.
    /// @param sequenceNumber The sequence number assigned to the deferred function call.
    /// @param selector code identifier for solvers to select relevant actions
    /// @param dataValues to be used by solvers in serving the user objective
    event ProxyPushed(
        address indexed proxyAddress,
        CallObject[] callObjs,
        uint256 sequenceNumber,
        bytes32 indexed selector,
        AdditionalData[] dataValues
    );

    /// @dev Emitted when a function call is pulled from a proxy contract for execution.
    /// @param returnData The ABI-encoded data payload returned from the function call.
    /// @param sequenceNumber The sequence number of the deferred function call.
    event ProxyPulled(bytes returnData, uint256 sequenceNumber);

    /// @dev Emitted when a function call is executed immediately via a proxy contract.
    /// @param proxyAddress The address of the proxy contract where the function call is executed.
    /// @param callObjs The CallObject containing the function call details.
    event ProxyExecuted(address indexed proxyAddress, CallObject[] callObjs);

    /// @notice Constructs a new contract instance - usually called by the Laminator contract
    /// @dev Initializes the contract, setting the call breaker address.
    /// @param _callBreaker The address of the laminator contract.
    constructor(address _callBreaker) {
        if (_callBreaker == address(0)) {
            revert AddressZero();
        }
        callBreaker = ICallBreaker(_callBreaker);
    }

    /// @notice Computes the deterministic address for a proxy contract for the given owner.
    /// @dev Uses the CREATE2 opcode to calculate the address for the proxy contract.
    ///      The proxy address is generated deterministically based on the owner's address,
    ///      the bytecode, and the salt.
    /// @param owner The address for which to compute the proxy address.
    /// @return The computed proxy address.
    function computeProxyAddress(address owner) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(owner));
        bytes memory constructorArgs = abi.encode(address(this), address(callBreaker), owner); // Encode the constructor arguments
        bytes memory bytecode = abi.encodePacked(type(LaminatedProxy).creationCode, constructorArgs); // Append the constructor arguments to the bytecode

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        return address(uint160(uint256(hash)));
    }

    /// @notice Gets the next sequence number of the LaminatedProxy associated with the sender.
    /// @return sequenceNumber The sequence number of the next deferred function call.
    function getNextSeqNumber() public view returns (uint256) {
        address addr = computeProxyAddress(msg.sender);
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        if (size == 0) {
            return 0;
        } else {
            return LaminatedProxy(payable(addr)).count();
        }
    }

    /// @notice Calls the `push` function into the LaminatedProxy associated with the sender.
    /// @dev Encodes the provided calldata and calls it into the `push` function of the proxy contract.
    ///      A new proxy will be created if one does not already exist for the sender.
    /// @param cData The calldata to be pushed.
    /// @param delay The delay for when the call can be executed.
    /// @param selector code identifier for solvers to select relevant actions
    /// @param dataValues to be used by solvers in serving the user objective
    /// @return sequenceNumber The sequence number of the deferred function call.
    function pushToProxy(
        bytes calldata cData,
        uint32 delay,
        bytes32 selector,
        AdditionalData[] memory dataValues
    ) external returns (uint256 sequenceNumber) {
        LaminatedProxy proxy = LaminatedProxy(payable(_getOrCreateProxy(msg.sender)));

        sequenceNumber = proxy.push(cData, delay);

        CallObject[] memory callObjs = abi.decode(cData, (CallObject[]));
        emit ProxyPushed(address(proxy), callObjs, sequenceNumber, selector, dataValues);
    }

    /// @notice Gets the proxy address for the sender or creates a new one if it doesn't exist.
    /// @dev Computes the proxy address for the sender using `computeProxyAddress`. If a proxy doesn't
    ///      already exist, it will be created using the `create2` Ethereum opcode.
    ///      An event `ProxyCreated` is emitted if a new proxy is created.
    /// @return proxyAddress The address of the proxy contract for the sender.
    function _getOrCreateProxy(address sender) internal returns (address) {
        address proxyAddress = computeProxyAddress(sender);

        // Check if the proxy contract already exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(proxyAddress)
        }

        if (codeSize == 0) {
            // Create a new proxy contract using create2
            // Encode the constructor arguments and append the constructor arguments to the bytecode
            bytes32 salt = keccak256(abi.encodePacked(sender));
            bytes memory constructorArgs = abi.encode(address(this), address(callBreaker), sender);
            bytes memory bytecode = abi.encodePacked(type(LaminatedProxy).creationCode, constructorArgs);

            assembly {
                proxyAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
            }

            emit ProxyCreated(sender, proxyAddress);
        }

        return proxyAddress;
    }
}
