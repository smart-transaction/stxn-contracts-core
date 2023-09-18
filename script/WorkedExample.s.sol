// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../src/examples/SelfCheckout.sol";
import "../src/examples/MyErc20.sol";

contract WorkedExampleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
        uint256 pusherPrivateKey = vm.envUint("PUSHER_PRIVATE_KEY2");
        uint256 fillerPrivateKey = vm.envUint("FILLER_PRIVATE_KEY3");

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

        // give the filler 20 erc20b
        erc20b.mint(filler, 20);

        // compute the pusher laminated address
        address payable pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        vm.label(address(laminator), "laminator");
        vm.label(address(callbreaker), "callbreaker");
        vm.label(address(erc20a), "erc20a");
        vm.label(address(erc20b), "erc20b");
        vm.label(pusherLaminated, "pusherLaminated");

        // set up a selfcheckout
        SelfCheckout selfcheckout =
            new SelfCheckout(pusherLaminated, address(erc20a), address(erc20b), address(callbreaker));

        vm.stopBroadcast();

        // THIS HAPPENS IN USER LAND
        vm.startBroadcast(pusherPrivateKey);
        // laminate your erc20a
        erc20a.transfer(pusherLaminated, 10);
        // pusher pushes its call to the selfcheckout
        CallObject memory pusherCallObj = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256)", 10)
        });
        uint256 laminatorSequenceNumber = laminator.pushToProxy(abi.encode(pusherCallObj), 1);
        vm.stopBroadcast();
        // END USER LAND

        // go forward in time
        vm.roll(block.number + 1);

        // THIS SHOULD ALL HAPPEN IN SOLVER LAND
        vm.startBroadcast(fillerPrivateKey);
        // filler fills the order
        // start by setting the selfcheckout to be the filler!
        selfcheckout.setTokenDest(filler);
        // now populate the time turner with calls.
        CallObject[] memory callObjs = new CallObject[](3);
        ReturnObject[] memory returnObjs = new ReturnObject[](3);
        // first we're going to call takeSomeAtokenFromOwner by pulling from the laminator
        CallObject memory cobj = CallObject({
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        // should return nothing.
        ReturnObject memory robj = ReturnObject({returnvalue: ""});
        callObjs[0] = cobj;
        returnObjs[0] = robj;
        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
        cobj = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", 20)
        });
        // return object is still nothing
        callObjs[1] = cobj;
        returnObjs[1] = robj;
        // then we'll call checkBalance
        cobj = CallObject({
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkBalance()")
        });
        // return object is still nothing
        callObjs[2] = cobj;
        returnObjs[2] = robj;

        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs));
        vm.stopBroadcast();
        // END SOLVER LAND

        // check the state of all the contracts now.
        // pusher should have 20 erc20b and 0 erc20a
        assert(erc20a.balanceOf(pusher) == 0);
        assert(erc20b.balanceOf(pusher) == 20);
        // filler should have 0 erc20b and 10 erc20a
        assert(erc20a.balanceOf(filler) == 10);
        assert(erc20b.balanceOf(filler) == 0);
        // portal should be closed
        assert(!callbreaker.isPortalOpen());
        // nothing should be scheduled in the laminator
        (bool init, CallObject memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assert(!init);
    }
}
