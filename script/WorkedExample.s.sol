// SPDX-License-Identifier: UNLICENSED
pragma solidity ^=0.8.20;

import "forge-std/Script.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";

contract WorkedExampleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Laminator laminator = new Laminator();
        CallBreaker callbreaker = new CallBreaker();

        // two erc20s for a selfcheckout
        IERC20 erc20a = new ERC20();
        IERC20 erc20b = new ERC20();

        // make a dummy address for the pusher who wants to get their order filled
        address pusher = address(0x1234567890123456789012345678901234567890);
        // make a dummy address for the filler who wants to fill the order
        address filler = address(0x0987654321098765432109876543210987654321);
        
        // give the pusher 10 erc20a
        erc20a.mint(pusher, 10);

        // give the filler 20 erc20b
        erc20b.mint(filler, 20);

        // compute the pusher laminated address
        address pusherLaminated = laminator.computeProxyAddress(pusher);

        // pusher sends its erc20a to the laminated address
        vm.prank(pusher);
        erc20a.transfer(pusherLaminated, 10);

        // set up a selfcheckout
        SelfCheckout selfcheckout = new SelfCheckout(pusherLaminated, erc20a.address, erc20b.address, callbreaker.address);

        // pusher pushes its call to the selfcheckout
        // THIS HAPPENS IN USER LAND
        CallObject memory pusherCallObj = new CallObject( {
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("takeSomeAtokenFromOwner(uint256)", 10)
        });
        vm.prank(pusher);
        (bool success, bytes memory returnvalue) = laminator.pushToProxy(abi.encode(pusherCallObj));
        // get the laminator sequence number from the return value
        uint256 laminatorSequenceNumber = abi.decode(returnvalue, (uint256));
        // END USER LAND

        // go forward in time
        vm.warp(block.number + 1);

        // THIS SHOULD ALL HAPPEN IN SOLVER LAND
        // filler fills the order- time warp time.
        // start by setting the selfcheckout to be the filler!
        selfcheckout.setTokenDest(filler);
        // now populate the time turner with calls.
        CallObject[] memory callObjs = new CallObject[](3);
        ReturnObject[] memory returnObjs = new ReturnObject[](3);
        // first we're going to call takeSomeAtokenFromOwner by pulling from the laminator
        CallObject memory cobj = CallObject( {
            amount: 0,
            addr: pusherLaminated,
            gas: 1000000,
            callvalue: abi.encodeWithSignature("pull(uint256)", laminatorSequenceNumber)
        });
        // should return nothing.
        ReturnObject memory robj = ReturnObject( {
            returnvalue: ""
        });
        callObjs[0] = cobj;
        returnObjs[0] = robj;
        // then we'll call giveSomeBtokenToOwner and get the imbalance back to zero
        cobj = CallObject( {
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("giveSomeBtokenToOwner(uint256)", 20)
        });
        // return object is still nothing
        callObjs[1] = cobj;
        returnObjs[1] = robj;
        // then we'll call checkBalance
        cobj = CallObject( {
            amount: 0,
            addr: address(selfcheckout),
            gas: 1000000,
            callvalue: abi.encodeWithSignature("checkBalance()")
        });
        // return object is still nothing
        callObjs[2] = cobj;
        returnObjs[2] = robj;
        
        vm.prank(filler);
        (success, returnvalue) = callbreaker.verify(abi.encode(callObjs), abi.encode(returnObjs));
        // END SOLVER LAND

        // check the state of all the contracts now.
        // pusher should have 20 erc20b and 0 erc20a
        assertEq(erc20a.balanceOf(pusher), 0);
        assertEq(erc20b.balanceOf(pusher), 20);
        // filler should have 0 erc20b and 10 erc20a
        assertEq(erc20a.balanceOf(filler), 10);
        assertEq(erc20b.balanceOf(filler), 0);
        // portal should be closed
        assertEq(laminator.portalIsOpen(), false);
        // nothing should be scheduled in the laminator
        (bool init, bytes memory bs) = LaminatedProxy(pusherLaminated).viewDeferredCall(laminatorSequenceNumber);
        assertEq(init, false);

        vm.stopBroadcast();
    }
}
