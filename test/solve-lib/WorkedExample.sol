// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Vm.sol";

import "../../src/lamination/Laminator.sol";
import "../../src/timetravel/CallBreaker.sol";
import "../../test/examples/SelfCheckout.sol";
import "../../test/examples/MyErc20.sol";

contract WorkedExampleLib {
    CallBreaker public callbreaker;
    SelfCheckout public selfcheckout;
    address payable public pusherLaminated;
    Laminator public laminator;
    MyErc20 public erc20a;
    MyErc20 public erc20b;

    uint256 _tipWei = 100000000000000000;

    function deployerLand(address pusher, address filler) public {
        // Initializing contracts
        callbreaker = new CallBreaker();
        laminator = new Laminator(address(callbreaker));

        erc20a = new MyErc20("A", "A");
        erc20b = new MyErc20("B", "B");

        // give the pusher 10 erc20a
        erc20a.mint(pusher, 10);

        // give the filler 20 erc20b
        erc20b.mint(filler, 20);

        // compute the pusher laminated address
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        // set up a selfcheckout
        selfcheckout = new SelfCheckout(pusherLaminated, address(erc20a), address(erc20b), address(callbreaker));
    }

    // msg.sender here is the user. all transfers of funds and approvals are made by the user.
    function userLand() public returns (uint256) {
        // Userland operations
        pusherLaminated.transfer(1 ether);
        erc20a.transfer(pusherLaminated, 10);
        CallObject[] memory pusherCallObjs = new CallObject[](3);
        pusherCallObjs[0] = CallObject({amount: _tipWei, addr: address(callbreaker), gas: 10000000, callvalue: ""});
        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(erc20a),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(selfcheckout), 10)
        });
        pusherCallObjs[2] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256)", 10)
        });
        laminator.pushToProxy(abi.encode(pusherCallObjs), 1);

        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    // msg.sender here is the filler. all transfers of funds and approvals are made by the filler.
    function solverLand(uint256 laminatorSequenceNumber, address filler, uint256 x) public {
        erc20b.approve(address(selfcheckout), x);

        CallObject[] memory callObjs = new CallObject[](3);
        ReturnObject[] memory returnObjs = new ReturnObject[](3);

        callObjs[0] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        // should return a list of the return value of approve + takesomeatokenfrompusher in a list of returnobjects, abi packed, then stuck into another returnobject.
        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](3);
        returnObjsFromPull[0] = ReturnObject({returnvalue: ""});
        returnObjsFromPull[1] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[2] = ReturnObject({returnvalue: ""});

        returnObjs[0] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
        callObjs[1] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", x)
        });
        // return object is still nothing
        returnObjs[1] = ReturnObject({returnvalue: ""});

        // then we'll call checkBalance
        callObjs[2] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkBalance()")
        });
        // log what this callobject looks like
        // return object is still nothing
        returnObjs[2] = ReturnObject({returnvalue: ""});

        // Constructing something that'll decode happily
        bytes32[] memory keys = new bytes32[](5);
        keys[0] = keccak256(abi.encodePacked("tipYourBartender"));
        keys[1] = keccak256(abi.encodePacked("swapPartner"));
        keys[2] = keccak256(abi.encodePacked("pusherLaminated"));
        keys[3] = keccak256(abi.encodePacked("x"));
        keys[4] = keccak256(abi.encodePacked("seqNum"));
        bytes[] memory values = new bytes[](5);
        values[0] = abi.encodePacked(filler);
        values[1] = abi.encodePacked(filler);
        values[2] = abi.encode(pusherLaminated);
        values[3] = abi.encode(x);
        values[4] = abi.encode(laminatorSequenceNumber);
        bytes memory encodedData = abi.encode(keys, values);

        bytes32[] memory hintdicesKeys = new bytes32[](3);
        hintdicesKeys[0] = keccak256(abi.encode(callObjs[0]));
        hintdicesKeys[1] = keccak256(abi.encode(callObjs[1]));
        hintdicesKeys[2] = keccak256(abi.encode(callObjs[2]));
        uint256[] memory hintindicesVals = new uint256[](3);
        hintindicesVals[0] = 0;
        hintindicesVals[1] = 1;
        hintindicesVals[2] = 2;
        bytes memory hintindices = abi.encode(hintdicesKeys, hintindicesVals);

        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs), encodedData, hintindices);
    }
}
