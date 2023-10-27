// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../test/examples/SelfCheckout.sol";
import "../../test/examples/MyErc20.sol";
import "./CleanupUtility.sol";

contract WorkedExampleLib {
    CallBreaker public callbreaker;
    SelfCheckout public selfcheckout;
    address payable public pusherLaminated;
    Laminator public laminator;
    MyErc20 public erc20a;
    MyErc20 public erc20b;
    CleanupUtility public cleanupContract;

    function deployerLand(address pusher, address filler) public {
        // Initializing contracts
        laminator = new Laminator();
        callbreaker = new CallBreaker();
        erc20a = new MyErc20("A", "A");
        erc20b = new MyErc20("B", "B");

        // give the pusher 10 erc20a
        erc20a.mint(pusher, 10);

        // give the filler 20 erc20b
        erc20b.mint(filler, 20);

        cleanupContract = new CleanupUtility();

        // compute the pusher laminated address
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        // set up a selfcheckout
        selfcheckout = new SelfCheckout(pusherLaminated, address(erc20a), address(erc20b), address(callbreaker));
    }

    function userLand() public returns (uint256) {
        // Userland operations
        erc20a.transfer(pusherLaminated, 10);
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(erc20a),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(selfcheckout), 10)
        });

        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256)", 10)
        });
        laminator.pushToProxy(abi.encode(pusherCallObjs), 1);

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler, uint256 x) public {
        erc20b.approve(address(selfcheckout), x);

        // TODO: Refactor these parts further if necessary.
        CallObject[] memory callObjs = new CallObject[](5);
        ReturnObject[] memory returnObjs = new ReturnObject[](5);

        callObjs[0] = CallObject({
            amount: 0,
            addr: address(cleanupContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "preClean(address,address,address,uint256,bytes)",
                address(callbreaker),
                selfcheckout,
                pusherLaminated,
                laminatorSequenceNumber,
                abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", x)
            )
        });
        returnObjs[0] = ReturnObject({returnvalue: ""});

        // first we're going to call takeSomeAtokenFromOwner by pulling from the laminator
        callObjs[1] = CallObject({
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
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
        callObjs[2] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", x)
        });
        // return object is still nothing
        returnObjs[2] = ReturnObject({returnvalue: ""});

        // then we'll call checkBalance
        callObjs[3] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkBalance()")
        });
        // log what this callobject looks like
        // return object is still nothing
        returnObjs[3] = ReturnObject({returnvalue: ""});

        // finally we'll call cleanup
        callObjs[4] = CallObject({
            amount: 0,
            addr: address(cleanupContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "cleanup(address,address,address,uint256,bytes)",
                address(callbreaker),
                address(selfcheckout),
                pusherLaminated,
                laminatorSequenceNumber,
                abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", x)
                )
        });
        // return object is still nothing
        returnObjs[4] = ReturnObject({returnvalue: ""});
        
        // Constructing something that'll decode happily
        bytes32[] memory keys = new bytes32[](1);
        keys[0] = keccak256(abi.encodePacked("swapPartner"));
        bytes[] memory values = new bytes[](1);
        values[0] = abi.encode(filler);
        bytes memory encodedData = abi.encode(keys, values);

        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData);
    }
}
