// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "src/timetravel/CallBreaker.sol";
import "src/timetravel/SmarterContract.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

interface IDisbursalContract {
    function spendCoins(address[] calldata _receivers, uint256[] calldata _amounts) external;
}

/**
 * @notice This is an POC example of a schedular which also fetches data at execution time from the SOLVER
 *  It schedules token dirbursal of KITN tokens and after evert disbursal schedule the next call for the same
 *  acting like an on chain cron job for distributing tokens to its users. Now, since the list of recievers keeps
 *  changing, the list of users and amounts are provided by the solver at execution time based on reports generated
 *  in the CleanApp backend
 */
contract CleanAppKITNDisbursal is SmarterContract, Ownable {
    struct DisbursalData {
        address[] receivers;
        uint256[] amounts;
    }

    bool public shouldContinue;
    address public callbreakerAddress;
    uint256 public nonce;
    IDisbursalContract public disbursalContract;

    constructor(address _callbreaker, address _disbursalContract) SmarterContract(_callbreaker) {
        callbreakerAddress = _callbreaker;
        disbursalContract = IDisbursalContract(_disbursalContract);
    }

    /**
     * @notice fetch params for spendcoins at MEVTime, get the correct arg from the data store and
     *  execute spendcoins on the disbursal contract. After disbursal schedule a next call to itself
     *  in the LaminatedProxy of the CleanApp.
     */
    function disburseKITNs() external {
        bytes32 key = keccak256(abi.encodePacked("KITNDisbursalData"));
        bytes memory data = CallBreaker(payable(callbreakerAddress)).fetchFromAssociatedDataStore(key);

        DisbursalData memory disbursalData = abi.decode(data, (DisbursalData));
        disbursalContract.spendCoins(disbursalData.receivers, disbursalData.amounts);
        nonce++;

        CallObject memory callObj = CallObject({
            amount: 0,
            addr: address(this),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("verifySignature()")
        });

        assertFutureCallTo(callObj, 1);
    }

    function setContinue(bool _shouldContinue) external onlyOwner {
        shouldContinue = _shouldContinue;
    }

    function verifySignature() public view {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash();

        bytes32 key = keccak256(abi.encodePacked("CleanAppSignature"));
        bytes memory signature = CallBreaker(payable(callbreakerAddress)).fetchFromAssociatedDataStore(key);

        (address signer,) = ECDSA.tryRecover(ethSignedMessageHash, signature);
        require(signer == owner(), "CleanAppKITNDisbursal: Verification Failed");
    }

    function getEthSignedMessageHash() public view returns (bytes32) {
        bytes32 messageHash = keccak256(abi.encodePacked(address(this), nonce));
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }
}
