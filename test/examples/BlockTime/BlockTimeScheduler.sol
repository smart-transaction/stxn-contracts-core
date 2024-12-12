// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/interfaces/IBlockTime.sol";
import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice This is an POC example of a block scheduler
 */
contract BlockTimeScheduler is SmarterContract, Ownable {

    struct BlockTimeData {
        IBlockTime.Chronicle[] chronicles;
        uint256 meanCurrentErathTime;
        BatchMintData mintTokensData;
    }

    struct BatchMintData {
        address[] receiver;
        uint256[] amounts;
    }

    bool public shouldContinue;
    address public callBreaker;
    IBlockTime public blockTime;

    constructor(address _callBreaker, address _blockTime, address _owner) SmarterContract(_callBreaker) Ownable(_owner) {
        callBreaker = _callBreaker;
        blockTime = IBlockTime(_blockTime);
        shouldContinue = true;
    }

    /// @dev The onlyOwner modifier will be later changed to execute calls through a governance proposal
    function updateTime() external onlyOwner {
        bytes32 key = keccak256(abi.encodePacked("MoveTimeData"));
        bytes memory data = CallBreaker(payable(callBreaker)).fetchFromAssociatedDataStore(key);

        BlockTimeData memory moveTimeData = abi.decode(data, (BlockTimeData));
        blockTime.moveTime(moveTimeData.chronicles, moveTimeData.meanCurrentErathTime, moveTimeData.mintTokensData.receiver, moveTimeData.mintTokensData.amounts);

        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("verifySignature(bytes)", data)
        });

        assertFutureCallTo(callObj, 1);
    }

    /// @notice function to be checked by Laminator before rescheduling a call to disburseKITNs
    /// @dev The onlyOwner modifier will be later changed to execute calls through a governance proposal
    function setContinue(bool _shouldContinue) external onlyOwner {
        shouldContinue = _shouldContinue;
    }
}