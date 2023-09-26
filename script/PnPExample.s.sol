// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../src/examples/PnP.sol";

contract PnPExampleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
        uint256 pusherPrivateKey = vm.envUint("PRIVATE_KEY2");
        uint256 fillerPrivateKey = vm.envUint("PRIVATE_KEY3");

        address pusher = vm.addr(pusherPrivateKey);
        address filler = vm.addr(fillerPrivateKey);

        vm.label(pusher, "pusher");
        vm.label(address(this), "deployer");
        vm.label(filler, "filler");

        // start deployer land
        vm.startBroadcast(deployerPrivateKey);

        Laminator laminator = new Laminator();
        CallBreaker callbreaker = new CallBreaker();
        PnP pnp = new PnP(address(callbreaker), pusherPrivateKey);

        // compute the pusher laminated address
        address payable pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        vm.label(address(laminator), "laminator");
        vm.label(address(callbreaker), "callbreaker");
        vm.label(address(pnp), "pnp");
        vm.label(pusherLaminated, "pusherLaminated");

        vm.stopBroadcast();

        /*
        // THIS HAPPENS IN USER LAND
        vm.startBroadcast(pusherPrivateKey);

        // pusher pushes its call to the selfcheckout
        // Create a list of CallObjects
        CallObject[] memory pusherCallObjs = new CallObject[](2);

        pusherCallObjs[0] = CallObject({
            amount: 0,
            addr: address(pnp),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(selfcheckout), 10)
        });

        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(pnp),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256)", 10)
        });
        uint256 laminatorSequenceNumber = laminator.pushToProxy(abi.encode(pusherCallObjs), 1);
        vm.stopBroadcast();
        // END USER LAND

        // go forward in time
        vm.roll(block.number + 1);

        // THIS SHOULD ALL HAPPEN IN SOLVER LAND
        vm.startBroadcast(fillerPrivateKey);

        // now populate the time turner with calls.
        CallObject[] memory callObjs = new CallObject[](5);
        ReturnObject[] memory returnObjs = new ReturnObject[](5);

        callObjs[0] = CallObject({
            amount: 0,
            addr: address(cleanupContract),
            gas: 1000000,
            callvalue: abi.encodeWithSignature(
                "preClean(address,address,address,uint256,uint256)",
                address(callbreaker),
                selfcheckout,
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
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", 20)
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
                "cleanup(address,address,address,uint256,uint256)",
                address(callbreaker),
                address(selfcheckout),
                pusherLaminated,
                laminatorSequenceNumber,
                20
                )
        });
        // return object is still nothing
        returnObjs[4] = ReturnObject({returnvalue: ""});

        callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs));
        vm.stopBroadcast();
        // END SOLVER LAND

        // portal should be closed
        assert(!callbreaker.isPortalOpen());
        // nothing should be scheduled in the laminator
        (bool init, CallObject[] memory co) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assert(!init);
        */
    }
}