// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../src/TrustedForwarder.sol";
import "src/lamination/Laminator.sol";
import "src/interfaces/IBlockTime.sol";

contract ForwarderTest is Test {
    TrustedForwarder trustedForwarder;
    LaminatedProxyMock laminatedProxy;
    IBlockTime blockTime;

    address owner = address(0x123);
    address operator1 = address(0xABC);
    address operator2 = address(0xDEF);
    address blockTimeImplementation;

    function setUp() public {
        trustedForwarder = new TrustedForwarder("TrustedForwarder");
        laminatedProxy = new LaminatedProxyMock();

        // Deploy BlockTime for encoding purposes only
        blockTimeImplementation = address(new BlockTime());
        blockTime = IBlockTime(blockTimeImplementation);

        vm.prank(owner);
        trustedForwarder.transferOwnership(owner);
    }

    function testForwardCallToLaminatedProxy() public {
        uint256 timestamp = block.timestamp;

        // Step 1: Encode call data using BlockTime
        bytes memory callData = abi.encodeWithSelector(blockTime.updateTime.selector, timestamp);

        // Step 2: Prepare pushToProxy parameters
        uint32 delay = 0;
        SolverData; // Empty for simplicity
        bytes memory pushCallData = abi.encodeWithSignature(
            "push(bytes,uint32,SolverData[])",
            callData,
            delay,
            dataValues
        );

        // Step 3: Sign the pushCallData
        bytes32 hash = keccak256(pushCallData);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Step 4: Whitelist operator and forward the call
        vm.prank(owner);
        trustedForwarder.whitelist(operator1);

        vm.prank(operator1);
        trustedForwarder.forwardCall(address(laminatedProxy), pushCallData, signature, operator1);

        // Step 5: Verify LaminatedProxy received the call
        uint256 sequenceNumber = laminatedProxy.sequence();
        assertEq(sequenceNumber, 1);
    }

    function testBlacklist() public {
        vm.prank(owner);
        trustedForwarder.blacklist(operator1);

        assertEq(trustedForwarder.isBlacklisted(operator1), true);
    }
}
