//TODO
// how will this work?
// first we'll create2 contract2.
// but create2 requires knowing the sender.
// so who's the sender?
// the sender is contract1.
// so contract1 will create2 contract2.
// but how will contract1 come into existence?
// contract1 will be created by contract2.
// ..... uhhhhhhhhh .......

// this looks like:
// contract1_addr = create2(contract1_code, contract2_addr (gotten from the future), salt)
// contract2_addr = create2(contract2_code, contract1_addr, salt)
// well, okay, guess we're executing pollard's rho :P

// not great.... but there is a solution with "init code":
// https://github.com/0age/metamorphic/blob/master/contracts/MetamorphicContractFactory.sol
// i'm NOT doing this right now. leaving as a todo

// SPDX-License-Identifier: UNKNOWN

pragma solidity ^=0.8.20;

import "../timetravel/CallBreaker.sol";

contract Contract1 {
    address private _callbreakerAddress;

    constructor(address callbreakerLocation) {
        _callbreakerAddress = callbreakerLocation;
    }

    function quine() external returns (address) {
        // CallObject memory callObj = CallObject({amount: 0, addr: address(this), gas: 1000000, callvalue: abi.encodeWithSignature("const_loop(uint16)", input)});

        // // call, hit the fallback.
        // (bool success, bytes memory returnvalue) = _callbreakerAddress.call(abi.encode(callObj));

        // if (!success) {
        //     revert("turner CallFailed");
        // }

        // // this one just returns whatever it gets from the turner.
        // return abi.decode(returnvalue, (uint16));

        // create2 at input address
        bytes32 salt = keccak256(abi.encode(3));
        return address(new Contract2{salt: salt}(_callbreakerAddress));
    }
}

contract Contract2 {
    address private _callbreakerAddress;

    constructor(address callbreakerLocation) {
        _callbreakerAddress = callbreakerLocation;
    }
}
