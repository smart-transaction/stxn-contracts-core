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

    event log_uint_here(uint256 x);
    event log_address_here(address x);

    function deployerLand(address pusher, address filler) public {
        // Initializing contracts
        emit log_uint_here(11);
        laminator = new Laminator();
        emit log_uint_here(12);
        callbreaker = new CallBreaker();
        emit log_uint_here(13);
        erc20a = new MyErc20("A", "A");
        emit log_address_here(address(erc20a));
        emit log_uint_here(14);
        erc20b = new MyErc20("B", "B");
        emit log_address_here(address(erc20b));
        emit log_uint_here(14);

        // give the pusher 10 erc20a
        erc20a.mint(pusher, 10);
        emit log_uint_here(15);

        // give the filler 20 erc20b
        erc20b.mint(filler, 20);
        emit log_uint_here(16);

        cleanupContract = new CleanupUtility();

        // compute the pusher laminated address
        pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        // set up a selfcheckout
        selfcheckout = new SelfCheckout(pusherLaminated, address(erc20a), address(erc20b), address(callbreaker));
    }

    function userLand() public returns (uint256) {
        // Userland operations
        emit log_uint_here(21);
        erc20a.transfer(pusherLaminated, 10);
        emit log_uint_here(22);
        CallObject[] memory pusherCallObjs = new CallObject[](2);
        emit log_uint_here(23);
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(erc20a),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(selfcheckout), 10)
        });
        emit log_uint_here(24);

        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256)", 10)
        });
        emit log_uint_here(25);
        laminator.pushToProxy(abi.encode(pusherCallObjs), 1);

        emit log_uint_here(26);
        return laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
    }

    function solverLand(uint256 laminatorSequenceNumber, address filler, uint256 x) public {
        emit log_uint_here(31);
        erc20b.approve(address(selfcheckout), x);
        emit log_uint_here(32);
        selfcheckout.setSwapPartner(filler);
        emit log_uint_here(33);

        // TODO: Refactor these parts further if necessary.
        emit log_uint_here(34);
        CallObject[] memory callObjs = new CallObject[](5);
        emit log_uint_here(35);
        ReturnObject[] memory returnObjs = new ReturnObject[](5);
        emit log_uint_here(36);

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
        emit log_uint_here(37);
        returnObjs[0] = ReturnObject({returnvalue: ""});
        emit log_uint_here(38);

        // first we're going to call takeSomeAtokenFromOwner by pulling from the laminator
        emit log_uint_here(39);
        callObjs[1] = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        // should return a list of the return value of approve + takesomeatokenfrompusher in a list of returnobjects, abi packed, then stuck into another returnobject.
        emit log_uint_here(40);
        ReturnObject[] memory returnObjsFromPull = new ReturnObject[](2);
        emit log_uint_here(41);
        returnObjsFromPull[0] = ReturnObject({returnvalue: abi.encode(true)});
        emit log_uint_here(42);
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        emit log_uint_here(43);
        // double encoding because first here second in pull()
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});
        emit log_uint_here(44);

        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
        callObjs[2] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", x)
        });
        emit log_uint_here(45);
        // return object is still nothing
        returnObjs[2] = ReturnObject({returnvalue: ""});

        emit log_uint_here(46);
        // then we'll call checkBalance
        callObjs[3] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkBalance()")
        });
        // log what this callobject looks like
        // return object is still nothing
        emit log_uint_here(47);
        returnObjs[3] = ReturnObject({returnvalue: ""});

        // finally we'll call cleanup
        emit log_uint_here(48);
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
        emit log_uint_here(49);
        // return object is still nothing
        returnObjs[4] = ReturnObject({returnvalue: ""});
        emit log_uint_here(50);

        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs));
        emit log_uint_here(51);
    }
}
