// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../src/timetravel/SmarterContract.sol";
import "../examples/CronDeposits.sol";
import "../examples/MyErc20.sol";

contract CronExampleLib {
    address payable public pusherLaminated;
    MyErc20 public erc20a;

    CallBreaker public callbreaker;
    CronDeposits public temporalHoneypot;
    Oracle public mevTimeOracle;
    Laminator public laminator;
    SmarterContract public smartercontract;

    function deployerLand(address pusher) public {
        // Initializing contracts
        laminator = new Laminator();
        callbreaker = new CallBreaker();
        mevTimeOracle = new Oracle();
        smartercontract = new SmarterContract(address(callbreaker));

        erc20a = new MyErc20("A", "A");

        // give the pusher 10 erc20a
        erc20a.mint(pusher, 10);

        temporalHoneypot = new CronDeposits(address(callbreaker), address(erc20a), address(smartercontract));

        // compute the pusher laminated address
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
    }

    // The user will now deposit 10 ERC20A tokens into the honeypot for 2 intervals (to represent subscription payment)
    function userLand() public returns (uint256, uint256) {
        // Userland operations
        erc20a.transfer(pusherLaminated, 10);
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(erc20a),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(temporalHoneypot), 5)
        });

        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(temporalHoneypot),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("deposit(uint256)", 5)
        });
        // We can also do 2 pushToProxy instances (where we push the first deposit in one with delay 2)
        // then push the second deposit in another with delay 6 (for example).
        // For now though we can just do it in two pushToProxy calls.
        uint256 sequenceNumberFirstPush = laminator.pushToProxy(abi.encode(pusherCallObjs), 2);
        uint256 sequenceNumberSecondPush = laminator.pushToProxy(abi.encode(pusherCallObjs), 6);

        return (sequenceNumberFirstPush, sequenceNumberSecondPush);
    }

    // The solver will pull the 10 erc20a from the temporal honeypot at the right time.
    function solverLand(uint256 laminatorSequenceNumber, address filler) public {
        // Grab some value from the MEV time oracle using partial function application
        // TODO: This should be eventually refactored into the verify call flow.
        // Block.timestamp is a dynamic value provided at MEV time
        bytes memory seed = abi.encode(uint256(5));
        bytes memory returnData = mevTimeOracle.returnArbitraryData(uint256(1), seed);

        uint256 x;
        // Just a fancy way of doing x = returnData lol
        assembly {
            x := mload(add(returnData, 0x20))
        }

        // Analogous to `setSwapPartner` except it sets the withdrawer at MEV time
        temporalHoneypot.setWithdrawer(filler);

        // TODO: Refactor these parts further if necessary.
        CallObject[] memory callObjs = new CallObject[](3);
        ReturnObject[] memory returnObjs = new ReturnObject[](3);

        // first we're going to call takeSomeAtokenFromOwner by pulling from the laminator
        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });

        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        // double encoding because first here second in pull()
        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        callObjs[1] = CallObject({
            amount: 0,
            addr: address(temporalHoneypot),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("withdraw(uint256)", x)
        });
        // return object is still nothing
        returnObjs[1] = ReturnObject({returnvalue: ""});

        // then we'll call checkBalance
        callObjs[2] = CallObject({
            amount: 0,
            addr: address(temporalHoneypot),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("ensureFundless()")
        });
        // log what this callobject looks like
        // return object is still nothing
        returnObjs[2] = ReturnObject({returnvalue: ""});

        // Constructing something that'll decode happily
        bytes32[] memory keys = new bytes32[](0);
        //keys[0] = keccak256(abi.encodePacked("key"));
        bytes[] memory values = new bytes[](0);
        //values[0] = abi.encode("value");
        bytes memory encodedData = abi.encode(keys, values);

        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData);
    }
}
