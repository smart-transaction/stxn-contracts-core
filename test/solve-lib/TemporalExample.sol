// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../examples/TemporalStates.sol";
import "../examples/MyErc20.sol";
import "../../src/timetravel/SmarterContract.sol";

contract TemporalExampleLib {
    address payable public pusherLaminated;
    MyErc20 public erc20a;

    CallBreaker public callbreaker;
    TemporalHoneypot public temporalHoneypot;
    MEVTimeOracle public mevTimeOracle;
    Laminator public laminator;
    SmarterContract public smartercontract;

    // Deploy all contracts, provide the user with 10 ERC20A tokens to deposit into the honeypot
    // The attacker will later attempt to pull the 10 ERC20A tokens from the honeypot
    function deployerLand(address pusher) public {
        // Initializing contracts
        laminator = new Laminator();
        callbreaker = new CallBreaker();
        mevTimeOracle = new MEVTimeOracle();
        erc20a = new MyErc20("A", "A");
        smartercontract = new SmarterContract(address(callbreaker));

        // give the pusher 10 erc20a
        erc20a.mint(pusher, 10);

        temporalHoneypot = new TemporalHoneypot(address(callbreaker), address(erc20a), address(smartercontract));

        // compute the pusher laminated address
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));
    }

    // The user will now deposit 10 ERC20A tokens into the honeypot
    function userLand() public returns (uint256) {
        // Userland operations
        erc20a.transfer(pusherLaminated, 10);
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(erc20a),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(temporalHoneypot), 10)
        });

        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(temporalHoneypot),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("deposit(uint256)", 10)
        });
        laminator.pushToProxy(abi.encode(pusherCallObjs), 1);

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    // The solver will pull the 10 erc20a from the temporal honeypot at the right time.
    function solverLand(uint256 laminatorSequenceNumber, address filler) public {
        // Grab some value from the MEV time oracle using partial function application
        // TODO: This should be eventually refactored into the verify call flow.
        // Block.timestamp is a dynamic value provided at MEV time
        bytes memory seed = abi.encode(uint256(10));
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

        // should return a list of the return value of approve + takesomeatokenfrompusher in a list of returnobjects, abi packed, then stuck into another returnobject.
        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        returnObjsFromPull[0] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        // double encoding because first here second in pull()
        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
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
