# Smart Transactions Core Contracts

Smart transactions core contracts are a set of smart contracts that allow to create and manage transactions with temporal properties. Smart transactions are transactions that are executed at MEV time and queued up beforehand with a certain delay. For example, a smart transaction can be created to transfer a certain amount of tokens to a specific address when a certain date is reached, or to create some continuous scheduled transfer of funds to a specific address.

## Usage 

To begin development, run the following commands:

```bash
forge install
forge build
# Run test suite
forge test
```

## Call Flow Example

One such example of the usage of smart transactions is located inside the Worked Example test. This is a test that simulates the creation of a smart transaction that will swap a certain amount of tokens to a specific address when a certain date is reached. The test is divided into 3 parts:
    - Deployment of the contracts
    - Creation of the smart transaction from the user
    - Execution of the smart transaction (and thereby the swapping of funds) by the miner

### Deployment of the contracts

The first part of the test is the deployment of the contracts. The contracts that are deployed are the following:
    - ERC20 token contract
    - Smart transaction factory contract
    - Smart transaction executor contract

10 Token A are minted to the user and 20 Token B are minted to the executor. The executor contract is the contract that will execute the smart transaction when the time comes. The user will create the smart transaction and will receive the funds when the swap is fulfilled by the executor ('filler').

### Creation of the smart transaction from the user

The user queues up a call to the `approve` function to approve some arbitrary exchange to take 10 Token A at a fixed rate for 20 Token B in return at the time of fulfillment. The user then queues a call to the function to transfer 10 Token A to the exchange. The user queues the call by pushing the encoded calls to the `LaminatedProxy`, a mempool implementation for fulfillers of the swap to pull swaps from.

### Execution of the smart transaction by the miner

At a high level, the executor orchestrates a sequence of contract interactions and ensures their validity by calling the `verify` function at the end. Here, in order to fulfill the swap, the solver specifically first prepares calls and expected response states: 
  - preClean Call
  - Setting up Approval and Swapping Partner
  - Performing the swap (Taking 10 Token A, giving 20 Token B)
  - Checking balances (Ensuring that the swap was successful)
  - Cleanup Call

Then, verification of correct call execution takes place to conclude the transaction
