// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

contract QuickTest is Test {
  function testA() public {
    vm.startPrank(address(100));
    A a = new A();
    // cast compute-address 0x0000000000000000000000000000000000000064 --nonce 0
    // Computed Address: 0x86C56C43a1D19B06D54971C467bad4b25e4eF59e
    assertEq(address(a), 0x86C56C43a1D19B06D54971C467bad4b25e4eF59e);
  }

  function testCreate() public {
    vm.startPrank(address(100));
    new A();
    new A();
    new A();
  }
  
  function testCallers() public {
    address b = address(new B());
    bytes memory m = abi.encodeWithSignature("log_caller()");
    vm.startPrank(address(0xdeadbeef), address(0xcafebabe));
    b.call(m);
    b.delegatecall(m);
    b.staticcall(m);
    assembly {
      // The selector is stored in the variable `m` as bytes.
      // The first 32 bit slot of the variable `m` contains the length of the bytes array.
      // The next 4 bytes contain the selector.
      let result := callcode(gas(), b, 0, add(m,32), 4, 0, 0)
    }
  }

}

contract B is Test {

  function log_caller() public view returns (address, address) {
    return (msg.sender, tx.origin);
  }

}

contract A {
  constructor() public {
  }
}