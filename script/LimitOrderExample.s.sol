// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../test/examples/LimitOrder.sol";
import "../test/examples/MyErc20.sol";
import "./CleanupContract.sol";

// Call order:
// User approves for protocol to take 10A
// User provides protocol for 10A; wants 30B
// High slippage causes 10A to be worth 20B
// Swapper tries to prove 20B swap, gets reverted because it's not 30B
// 30B comes along sometime in future, succeeds on trade.
contract LimitOrderExampleScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
    uint256 pusherPrivateKey = vm.envUint("PRIVATE_KEY2");
    uint256 fillerPrivateKey = vm.envUint("PRIVATE_KEY3");

    function run() external {
        address pusher = vm.addr(pusherPrivateKey);
        address filler = vm.addr(fillerPrivateKey);

        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");

        // start deployer land
        vm.startBroadcast(deployerPrivateKey);

        Laminator laminator = new Laminator();
        CallBreaker callbreaker = new CallBreaker();

        // two erc20s for a selfcheckout
        MyErc20 erc20a = new MyErc20("A", "A");
        MyErc20 erc20b = new MyErc20("B", "B");

        // give the pusher 10 erc20a
        erc20a.mint(pusher, 10);

        // give the filler 30 erc20b
        erc20b.mint(filler, 30);

        // compute the pusher laminated address
        address payable pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        vm.label(address(laminator), "laminator");
        vm.label(address(callbreaker), "callbreaker");
        vm.label(address(erc20a), "erc20a");
        vm.label(address(erc20b), "erc20b");
        vm.label(pusherLaminated, "pusherLaminated");

        // set up a selfcheckout
        LimitOrder limitorder = new LimitOrder(pusherLaminated, address(erc20a), address(erc20b), address(callbreaker));

        vm.stopBroadcast();

        // THIS HAPPENS IN USER LAND
        vm.startBroadcast(pusherPrivateKey);
        // laminate your erc20a
        erc20a.transfer(pusherLaminated, 10);
        // pusher pushes its call to the selfcheckout
        // Create a list of CallObjects
        CallObject[] memory pusherCallObjs = new CallObject[](2);

        // approve selfcheckout to spend 10 erc20a on behalf of pusher
        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(erc20a),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(limitorder), 10)
        });

        // specify that each token A should be worth 3 B tokens
        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(limitorder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256,uint256)", 10, 3)
        });
        uint256 laminatorSequenceNumber = laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
        vm.stopBroadcast();
        // END USER LAND

        // go forward in time
        vm.roll(block.number + 1);

        // THIS SHOULD ALL HAPPEN IN SOLVER LAND
        vm.startBroadcast(fillerPrivateKey);
        // todo: do a quick approval- how are we going to wrap these up together in the future :|
        // todo: my concept is that the callbreaker .... allows you to execute code as yourself? idk?
        // this is gonna cost so much gas :|
        erc20b.approve(address(limitorder), 30);

        // deploy a cleanup contract to clean up the time turner
        CleanupContract cleanupContract = new CleanupContract();

        // filler fills the order
        // start by setting the selfcheckout to be the filler!
        limitorder.setSwapPartner(filler);
        // now populate the time turner with calls.
        CallObject[] memory callObjs = new CallObject[](5);
        ReturnObject[] memory returnObjs = new ReturnObject[](5);

        // Should expect pre-clean call with 20 to revert
        callObjs[0] = CallObject({
            amount: 0,
            addr: address(cleanupContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "preClean(address,address,address,uint256,uint256)",
                address(callbreaker),
                limitorder,
                pusherLaminated,
                laminatorSequenceNumber,
                20
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
            addr: address(limitorder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", 20)
        });
        // return object is still nothing
        returnObjs[2] = ReturnObject({returnvalue: ""});

        // then we'll call checkBalance
        callObjs[3] = CallObject({
            amount: 0,
            addr: address(limitorder),
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
                "cleanup(address,address,address,uint256,uint256)",
                address(callbreaker),
                address(limitorder),
                pusherLaminated,
                laminatorSequenceNumber,
                20
                )
        });
        // return object is still nothing
        returnObjs[4] = ReturnObject({returnvalue: ""});

        // Verify should revert here
        vm.expectRevert();
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs));

        vm.stopBroadcast();

        // Progress in time
        vm.roll(block.number + 1);

        vm.startBroadcast(fillerPrivateKey);
        // todo: do a quick approval- how are we going to wrap these up together in the future :|
        // todo: my concept is that the callbreaker .... allows you to execute code as yourself? idk?
        // this is gonna cost so much gas :|
        erc20b.approve(address(limitorder), 30);

        callObjs[0] = CallObject({
            amount: 0,
            addr: address(cleanupContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "preClean(address,address,address,uint256,uint256)",
                address(callbreaker),
                limitorder,
                pusherLaminated,
                laminatorSequenceNumber,
                30
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
        returnObjsFromPull[0] = ReturnObject({returnvalue: abi.encode(true)});
        returnObjsFromPull[1] = ReturnObject({returnvalue: ""});
        // double encoding because first here second in pull()
        returnObjs[1] = ReturnObject({returnvalue: abi.encode(abi.encode(returnObjsFromPull))});

        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
        callObjs[2] = CallObject({
            amount: 0,
            addr: address(limitorder),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", 30)
        });
        // return object is still nothing
        returnObjs[2] = ReturnObject({returnvalue: ""});

        // then we'll call checkBalance
        callObjs[3] = CallObject({
            amount: 0,
            addr: address(limitorder),
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
                "cleanup(address,address,address,uint256,uint256)",
                address(callbreaker),
                address(limitorder),
                pusherLaminated,
                laminatorSequenceNumber,
                30
                )
        });
        // return object is still nothing
        returnObjs[4] = ReturnObject({returnvalue: ""});

        // This time, verify should succeed
        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs));

        vm.stopBroadcast();

        // END SOLVER LAND

        // check the state of all the contracts now.
        // pusher should have 30 erc20b and 0 erc20a
        assert(erc20a.balanceOf(pusherLaminated) == 0);
        assert(erc20b.balanceOf(pusherLaminated) == 30);
        // filler should have 0 erc20b and 10 erc20a
        assert(erc20a.balanceOf(filler) == 10);
        assert(erc20b.balanceOf(filler) == 0);
        // portal should be closed
        assert(!callbreaker.isPortalOpen());
        // nothing should be scheduled in the laminator
        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assert(!init);
    }
}
