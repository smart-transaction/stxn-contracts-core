// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "src/utilities/Airdrop.sol";
import "test/utils/MockERC20Token.sol";

contract AirdropTest is Test {
    Airdrop public airdrop;
    MyErc20 public token;
    address public user = address(0xF977814e90dA44bFA03b6295A0616a897441aceC);
    bytes32 public merkleRoot;
    bytes32[] public proof = new bytes32[](2);
    uint256 public amount = 100;

    function setUp() public {
        vm.startPrank(user);
        console.log(user);
        token = new MyErc20("Test", "TK");

        airdrop = new Airdrop(
            0x767bc7038ef03a335942f18ae700472934278d1fc4050c95db1cb5105bbd46fe,
            address(token)
        );
        token.mint(address(airdrop), 100000);
        proof[
            0
        ] = 0x38d2966958ed6d36253aa44c7eb8211e07f2a5cd45f5ff8f89dffef01365bc53;
        proof[
            1
        ] = 0xccac033013a6c5c1820dcbec78b653d4b089d89efaac764326400359c6b2aef1;
        vm.stopPrank();
    }

    function testClaim() public {
        vm.prank(user);
        airdrop.claim(0, user, amount, proof);
        assertEq(token.balanceOf(user), amount);
    }

    function testDoubleClaimFails() public {
        vm.prank(user);
        airdrop.claim(0, user, amount, proof);
        vm.expectRevert("Tokens already claimed.");
        vm.prank(user);
        airdrop.claim(0, user, amount, proof);
    }

    function testInvalidProofFails() public {
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = keccak256(abi.encodePacked("wrong"));
        vm.expectRevert("Invalid proof");
        vm.prank(user);
        airdrop.claim(0, user, amount, invalidProof);
    }

    function testWrongAmount() public {
        uint256 wrongAmount = 200;
        vm.expectRevert("Invalid proof");
        vm.prank(user);
        airdrop.claim(0, user, wrongAmount, proof);
    }

    // function testNonExistentIndex() public {
    //     assertFalse(airdrop.isClaimed(2));
    // }
}
