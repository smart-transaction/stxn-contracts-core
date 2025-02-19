// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/interfaces/IBlockTime.sol";
import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/**
 * @notice This is an POC example of a block scheduler
 */
contract BlockTimeScheduler is SmarterContract, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TIME_SOLVER = keccak256("TIME_SOLVER");

    // TODO: To be used to reduce repeated external call to CallBreaker
    // struct BlockTimeData {
    //     IBlockTime.Chronicle[] chronicles;
    //     uint256 meanCurrentEarthTime;
    //     BatchMintData mintTokensData;
    // }

    // struct BatchMintData {
    //     address[] receiver;
    //     uint256[] amounts;
    // }

    bool public shouldContinue;
    address public callBreaker;
    IBlockTime public blockTime;

    constructor(address _callBreaker, address _blockTime, address _admin) SmarterContract(_callBreaker) {
        callBreaker = _callBreaker;
        blockTime = IBlockTime(_blockTime);
        shouldContinue = true;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /// @dev The onlyOwner modifier will be later changed to execute calls through a governance proposal
    function updateTime() external onlyRole(TIME_SOLVER) {
        bytes memory chroniclesData =
            CallBreaker(payable(callBreaker)).fetchFromAssociatedDataStore(keccak256(abi.encodePacked("Chronicles")));
        bytes memory meanTimeData = CallBreaker(payable(callBreaker)).fetchFromAssociatedDataStore(
            keccak256(abi.encodePacked("CurrentMeanTime"))
        );
        bytes memory recievers =
            CallBreaker(payable(callBreaker)).fetchFromAssociatedDataStore(keccak256(abi.encodePacked("Recievers")));
        bytes memory amounts =
            CallBreaker(payable(callBreaker)).fetchFromAssociatedDataStore(keccak256(abi.encodePacked("Amounts")));

        blockTime.moveTime(
            abi.decode(chroniclesData, (IBlockTime.Chronicle[])),
            abi.decode(meanTimeData, (uint256)),
            abi.decode(recievers, (address[])),
            abi.decode(amounts, (uint256[]))
        );
    }

    /// @notice function to be checked by Laminator before rescheduling a call to disburseKITNs
    /// @dev The onlyOwner modifier will be later changed to execute calls through a governance proposal
    function setContinue(bool _shouldContinue) external onlyRole(ADMIN_ROLE) {
        shouldContinue = _shouldContinue;
    }
}
