// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

contract Faucet {
    //state variable to keep track of owner and amount of ETHER to dispense
    address public owner;
    uint public amountAllowed = 0.5 ether;


    //mapping to keep track of requested rokens
    //Address and blocktime + 1 day is saved in TimeLock
    mapping(address => uint) public lockTime;


    //constructor to set the owner
    constructor() payable { 
	owner = msg.sender;
    }

    //function modifier
    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this function.");
        _; 
    }


    //function to change the owner.  Only the owner of the contract can call this function
    function setOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }


    //function to set the amount allowable to be claimed. Only the owner can call this function
    function setAmountallowed(uint setAmountAllowed) public onlyOwner {
        amountAllowed = setAmountAllowed;
    }

    // function to add funds to the smart contract
    function addFunds() public payable { }

    //function to send tokens from faucet to an address
    function requestTokens(address payable _requestor) public payable onlyOwner {

        //perform a few checks to make sure function can execute
        require(block.timestamp > lockTime[_requestor], "Lock time has not expired. Please try again later");
        require(address(this).balance > amountAllowed, "Not enough funds in the faucet.");

        //if the balance of this contract is greater then the requested amount send funds
        _requestor.transfer(0.5 ether);        
 
        //updates locktime 1 day from now
        lockTime[_requestor] = block.timestamp + 1 days;
    }
}