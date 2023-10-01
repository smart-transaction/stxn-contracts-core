// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";

import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../src/examples/SelfCheckout.sol";
import "../src/examples/MyErc20.sol";
import "./CleanupContract.sol";

contract WorkedExampleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
        uint256 pusherPrivateKey = vm.envUint("PUSHER_PRIVATE_KEY2");
        uint256 fillerPrivateKey = vm.envUint("FILLER_PRIVATE_KEY3");
        address laminatoraddr = vm.envAddress("laminator");
        address erc20aaddr = vm.envAddress("erc20a");
        address erc20baddr = vm.envAddress("erc20b");
        address selfcheckoutaddr = vm.envAddress("selfcheckout");
        address payable callbreakeraddr = payable(vm.envAddress("callbreaker"));

        Laminator laminator = Laminator(laminatoraddr);
        MyErc20 erc20a = MyErc20(erc20aaddr);
        MyErc20 erc20b = MyErc20(erc20baddr);
        SelfCheckout selfcheckout = SelfCheckout(selfcheckoutaddr);
        CallBreaker callbreaker = CallBreaker(callbreakeraddr);

        address pusher = vm.addr(pusherPrivateKey);
        address filler = vm.addr(fillerPrivateKey);

        address payable pusherLaminated = payable(laminator.computeProxyAddress(pusher));

        vm.startBroadcast(deployerPrivateKey);
        erc20a.mint(pusher, 10);
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
            callvalue: abi.encodeWithSignature("approve(address,uint256)", address(selfcheckout), 10)
        });

        pusherCallObjs[1] = CallObject({
            amount: 0,
            addr: address(selfcheckout),
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
    }
}
