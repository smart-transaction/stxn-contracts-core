// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/utilities/BlockTime.sol";
import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

interface IBlockTime {
    function moveTime(BlockTime.Chronicle[] calldata chronicles, uint256 meanCurrentEarthTime) external;
}

/**
 * @notice This is an POC example of a block scheduler
 */
contract BlockTimeScheduler is SmarterContract, Ownable {

    struct BlockTimeData {
        BlockTime.Chronicle[] chronicles;
        uint256 meanCurrentErathTime;
    }

    bool public shouldContinue;
    address public callBreaker;
    IBlockTime public blockTime;

    constructor(address _callBreaker, address _blockTime, address _owner) SmarterContract(_callBreaker) Ownable(_owner) {
        callBreaker = _callBreaker;
        blockTime = IBlockTime(_blockTime);
        shouldContinue = true;
    }

    function updateTime() external {
        bytes32 key = keccak256(abi.encodePacked("MoveTimeData"));
        bytes memory data = CallBreaker(payable(callBreaker)).fetchFromAssociatedDataStore(key);

        BlockTimeData memory moveTimeData = abi.decode(data, (BlockTimeData));
        blockTime.moveTime(moveTimeData.chronicles, moveTimeData.meanCurrentErathTime);

        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("verifySignature(bytes)", data)
        });

        assertFutureCallTo(callObj, 1);
    }

    /// @notice function to be checked by Laminator before rescheduling a call to disburseKITNs
    function setContinue(bool _shouldContinue) external onlyOwner {
        shouldContinue = _shouldContinue;
    }

        /// @notice function to be called by solver to ensure a succesful and valid call
    function verifySignature(bytes calldata /* data */ ) public view {
        bytes32 key = keccak256(abi.encodePacked("CleanAppSignature"));
        bytes memory signature = CallBreaker(payable(callBreaker)).fetchFromAssociatedDataStore(key);

        // for the purpose of the POC we are verifying a standard value passed as signature
        require(keccak256(signature) == keccak256(abi.encode("signature")));

        /// @dev the following can be used to verify the source of the data
        // bytes32 ethSignedMessageHash = getEthSignedMessageHash(data);
        // (address signer,) = ECDSA.tryRecover(ethSignedMessageHash, signature);
        // require(signer == owner(), "CleanAppKITNDisbursal: Verification Failed");
    }

    function getEthSignedMessageHash(bytes memory data) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", data));
    }
}