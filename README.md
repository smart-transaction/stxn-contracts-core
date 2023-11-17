# Smart Transactions Core Contracts

Smart transactions core contracts are a set of smart contracts that allow for the creation and management of transactions with temporal properties. Smart transactions are transactions that are executed at MEV time. Users queue up calls in the present for execution in the future by pushing them to a Mempool (LaminatedProxy). Users can configure the calls in several ways, such as preventing frontruns and backruns or arranging them to be executable only after a delay. For example, a smart transaction can be created to transfer a balance of tokens to a specific address when a certain time is reached, or to create continuous scheduled transfers of funds to a specific address (I.e. like a subscription payment).

## Usage 

To begin development, run the following commands:

```bash
forge install
forge build
# Run test suite
forge test
```

## Call Flow Example

The `Worked Example` is an example of using smart transactions to exchange tokens at a user-specified rate. Suppose Alice wants to exchange 10 Token A’s for 20 Token B’s. Alice writes a smart contract `SelfCheckout` that enforces an `invariant`; Alice’s 10 Token A’s must be exchanged for at least 20 token B. A solver, Bob, would fulfill the transaction at MEV-Time. The test is divided into 3 parts:
    - Deployment of the contracts
    - Creation of the smart transaction from the user
    - Execution of the smart transaction (and thereby the swapping of funds) by the miner

### Deployment of the contracts

The first part of the test deploys some ERC20 tokens and Alice’s smart transaction contract and mempool:
    - ERC20 token contracts (ERC20 A, ERC20 B)
    - Mempool factory contract (`Laminator`) & an instance of the mempool (`LaminatedProxy`)
    - Alice’s Self-Checkout contract

To set up the test scenario, we mint 10 Token As to the user Alice and 20 Token Bs to Bob, the fulfiller of the trade (hereby referred to as the “filler”). After Alice queues up the series of calls she wants to be executed, Bob will `pull` to execute them at MEV-Time along with arbitrary calls of his own. The transaction will not revert as long as the end result is reached: Alice has swapped 20 Tokens with Bob.

These setup steps ensure that the filler and the user both have the requisite liquidity to complete the swap to proceed with the demonstration.

### Creation of the smart transaction from the user

Let’s dive deeper into how Alice creates smart transactions. Generally, users use their `LaminatedProxy` to queue up calls they want executed in the future by pushing an `abi.encoded` list of `CallObjects` to the mempool.

The user queues up a call to the `approve` function to approve some arbitrary exchange to take 10 Token A at a fixed rate for 20 Token B in return at the time of fulfillment. The user then queues a call to the function to transfer 10 Token A to the exchange. The user queues the call by pushing the encoded calls to the `LaminatedProxy`, a mempool implementation for fulfillers of the swap to pull swaps from.

```solidity
push(bytes memory input, uint256 delay)
```

Pushing the series of transactions stores calls within the `LaminatedProxy`’s storage for a solver, Bob, to `pull` later. The sequence number that `push` returns is what Bob will use to specify the series of transactions he wants to execute. When Bob calls `pull(uint256 seqNumber)` on the transactions Alice has pushed, Bob executes Alice’s calls sequentially. In some cases, Alice may add `copyCurrentJob` to conditionally repeat calls that she had pushed.

In order for Alice to enforce invariants on her own calls (e.g. for her to make sure that Bob gives her 20 Token B back in exchange for her 10 token A), she uses utilities from `SmarterContract` to introspect on the context of her call. In this example, she uses the `assertFutureCallTo` function.

```solidity
assertFutureCallTo(CallObject memory callObj, uint256 hintdex)
```

In the case of the WorkedExample, when Alice queues up a transaction for the SelfCheckout to take her tokens the SelfCheckout asserts that Bob makes a call to `checkBalance` at a certain index. Without further assertions from Alice to prevent Bob from frontrunning or backrunning the transaction, Bob can make any calls of his own in any order as long as `checkBalance` is where it’s supposed to be (i.e. the fourth call). Without Alice’s SelfCheckout contract scheduling this call, Bob wouldn’t need to give Alice 20 Tokens!

Alice queues up 3 calls for her Smart Transaction:
    - A call to `tip` the solver by some predetermined amount
    - A call to approve the SelfCheckout contract to take 10 Token A from Alice’s balance
    - A call to transfer the 10 Token A from Alice to the SelfCheckout.
      - Note that this call will assert a future call to `checkBalance()`.

If Alice no longer wants to execute the transactions she had previously pushed (or if it is not getting picked up by solvers), user can cancel them by using `cancelPending(uint256 callSequenceNumber)` or `cancelAllPending()`.

### Execution of the smart transaction by the miner

At a high level, the solver orchestrates a sequence of arbitrary contract calls within the bounds of Alice’s assertions and ensures their validity by calling the `verify` function at the end. Here, Bob has knowledge of the transactions that Alice wants him to execute at MEV Time. Bob can execute whatever calls he wants, **as long as he fulfills Alice’s assertions**.

Here, in order to fulfill the swap, the solver constructs a list of `CallObjects[]` and `ReturnObjects[]`. The `CallObjects` are what Bob will execute in `verify` – a function in the `CallBreaker` that allows Bob to resolve Alice’s transaction. The CallBreaker uses Bob’s provided list of `ReturnObjects` to assert that Bob’s calls reached a correct state.

The solver also provides a list of key-value pairs of data associated with the transaction (for example, the address of who Alice should tip, the amount of token B that Bob should give Alice, who Alice is swapping with, etc.). Lastly, the solver provides a `hintdices`: Bob maps his calls to indices to verify that the calls were executed at the right indices.

In the WorkedExample, Bob executes the following:
    - A call to `pull` Alice’s series of transactions.
    - A call to `approve` the contract to take `x` token B (in this case, 20)
    - A call to `giveSomeBtokenToOwner` to give `x` token B to Alice
    - A call to `checkBalance` (the call Alice previously asserted had to take place at the 4th index)

Finally, verification of the call execution takes place to conclude the transaction. To verify that the calls were successfully executed with the intended return values, the `CallBreaker` executes each individual call, and checks the calls’ return values against a provided list of return values. During the verification process, the return value of each call and the call itself form ‘balanced’ call-return value pairs. The `verify` check will pass if the calls execute as stated. 
