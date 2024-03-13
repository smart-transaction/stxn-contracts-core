pragma solidity >=0.6.2 <0.9.0;

contract ExampleContract {
    function exampleFunction() public pure returns (string memory) {
        // call into da time turner 
        ReturnObject memory ro = time_turner.Call ({ExampleContract address, exampleFunction, gas_left, arguments}, return_value);

        return ro.returnvalue;
    }
}


function exampleFunction() public payable ensureTurnerOpen returns (string memory) {
    (CallObject memory co, ReturnObject memory ro) = getCurrentExecutingPair()

    assert(co.amount == msg.value && co.gas == gas_left && co.addr == address(this) && co.callvalue == abi.encodeWithSignature("exampleFunction()"))
    assert(ro.returnvalue == return_value)

    return return_value
}