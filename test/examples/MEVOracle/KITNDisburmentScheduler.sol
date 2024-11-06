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
 * It schedules token dirbursal of KITN tokens and after evert disbursal schedule the next call for the same
 * acting like an on chain cron job for distributing tokens to its users. Now, since the list of recievers keeps
 * changing, the list of users and amounts are provided by the solver at execution time based on reports generated
 * in the CleanApp backend
 */
contract KITNDisburmentScheduler is SmarterContract, Ownable {
    struct DisbursalData {
        address[] receivers;
        uint256[] amounts;
    }

    bool public shouldContinue;
    address public callbreakerAddress;
    IDisbursalContract public disbursalContract;

    constructor(address _callbreaker, address _disbursalContract, address _owner) SmarterContract(_callbreaker) {
        callbreakerAddress = _callbreaker;
        disbursalContract = IDisbursalContract(_disbursalContract);
        shouldContinue = true;
        _transferOwnership(_owner);
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
        bytes memory signature = CallBreaker(payable(callbreakerAddress)).fetchFromAssociatedDataStore(key);

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
