// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "src/tokens/AshToken.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @notice This scheduler contract is responsible for minting ASH tokens on chain
 * It schedules on chain call objects to be executed by the solver whenever a new block is produced
 * It recieves the calculated amounts for three different proposals from the solver through MEV time getter
 * The values are used to execute mint on three different ASH token contracts corresponsing to different proposals
 */
contract AshMintScheduler is SmarterContract, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant ASH_MINTER = keccak256("ASH_MINTER");

    struct AshMintData {
        uint256 ashBIAmount;
        uint256 ashBAmount;
        uint256 ashBISAmount;
        uint256 blockNumber;
    }

    bool public shouldContinue;
    address public callbreakerAddress;
    address public treasury;

    AshToken public ashTokenBI; // ASH = BURNED - ISSUED
    AshToken public ashTokenB; // ASH = BURNED ETH
    AshToken public ashTokenBIS; // ASH = BURNED - ISSUED - SCORE

    event AshAddressUpdated(address _ashBI, address _ashB, address _ashBIS);
    event TreasuryUpdated(address _oldTreasury, address _newTreasury);

    error ZeroAddress();

    constructor(address _callbreaker, address _teasury, address _ashBI, address _ashB, address _ashBIS, address _admin)
        SmarterContract(_callbreaker)
    {
        if (_teasury == address(0) || _ashBI == address(0) || _ashBI == address(0) || _ashBI == address(0)) {
            revert ZeroAddress();
        }

        callbreakerAddress = _callbreaker;
        treasury = _teasury;
        ashTokenBI = AshToken(_ashBI);
        ashTokenB = AshToken(_ashB);
        ashTokenBIS = AshToken(_ashBIS);
        shouldContinue = true;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
    }

    /**
     * @notice fetch params for mint amounts at MEVTime
     * After minting schedule the next call to itself in the LaminatedProxy of the AshMinter.
     */
    function mintAsh() external onlyRole(ASH_MINTER) {
        bytes32 key = keccak256(abi.encodePacked("AshMintData"));
        bytes memory data = CallBreaker(payable(callbreakerAddress)).fetchFromAssociatedDataStore(key);

        AshMintData memory mintData = abi.decode(data, (AshMintData));
        ashTokenBI.mint(treasury, mintData.ashBIAmount, mintData.blockNumber);
        ashTokenB.mint(treasury, mintData.ashBAmount, mintData.blockNumber);
        ashTokenBIS.mint(treasury, mintData.ashBISAmount, mintData.blockNumber);

        // TODO: Assert Balance check by calling a verification function on Token Balances
        // CallObject memory callObj = CallObject({
        //     amount: 0,
        //     addr: address(this),
        //     gas: 10000000,
        //     callvalue: abi.encodeWithSignature("assertBalance()")
        // });

        // assertFutureCallTo(callObj, 0);
    }

    function updateAshAddresses(address _ashBI, address _ashB, address _ashBIS) external onlyRole(ADMIN_ROLE) {
        if (_ashBI == address(0) || _ashBI == address(0) || _ashBI == address(0)) {
            revert ZeroAddress();
        }

        ashTokenBI = AshToken(_ashBI);
        ashTokenB = AshToken(_ashB);
        ashTokenBIS = AshToken(_ashBIS);

        emit AshAddressUpdated(_ashBI, _ashB, _ashBIS);
    }

    function updateTreasury(address _newTreasury) external onlyRole(ADMIN_ROLE) {
        if (_newTreasury == address(0)) {
            revert ZeroAddress();
        }

        emit TreasuryUpdated(treasury, _newTreasury);
        treasury = _newTreasury;
    }

    /// @notice function to be checked by LaminatedProxy before rescheduling a call to mintAsh
    function setContinue(bool _shouldContinue) external onlyRole(ADMIN_ROLE) {
        shouldContinue = _shouldContinue;
    }
}
