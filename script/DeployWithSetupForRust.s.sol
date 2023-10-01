// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Script.sol";
import "../src/lamination/Laminator.sol";
import "../src/timetravel/CallBreaker.sol";
import "../src/examples/SelfCheckout.sol";
import "../src/examples/MyErc20.sol";
import "./CleanupContract.sol";

contract DeployerScript is Script {
    event LogAddressWithMessage(address addr, string message);

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY1");
        uint256 pusherPrivateKey = vm.envUint("PUSHER_PRIVATE_KEY2");
        uint256 fillerPrivateKey = vm.envUint("FILLER_PRIVATE_KEY3");

        address pusher = vm.addr(pusherPrivateKey);
        address filler = vm.addr(fillerPrivateKey);

        vm.label(pusher, "pusher");
        emit LogAddressWithMessage(pusher, "pusher");
        vm.label(address(this), "deployer");
        emit LogAddressWithMessage(address(this), "deployer");
        vm.label(filler, "filler");
        emit LogAddressWithMessage(filler, "filler");

        // start deployer land
        vm.startBroadcast(deployerPrivateKey);

        Laminator laminator = new Laminator();
        emit LogAddressWithMessage(address(laminator), "laminator");
        CallBreaker callbreaker = new CallBreaker();
        emit LogAddressWithMessage(address(callbreaker), "callbreaker");

        // two erc20s for a selfcheckout
        MyErc20 erc20a = new MyErc20("A", "A");
        emit LogAddressWithMessage(address(erc20a), "erc20a");
        MyErc20 erc20b = new MyErc20("B", "B");
        emit LogAddressWithMessage(address(erc20b), "erc20b");

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
        emit LogAddressWithMessage(address(selfcheckout), "selfcheckout");

        vm.stopBroadcast();
    }
}
