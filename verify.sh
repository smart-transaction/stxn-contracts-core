#!/bin/bash
# Execute this scipt with: ./verify.sh <CONTRACT NAME> <CONTRACT ADDRESS>

# Get the contract name
CONTRACT=$1

# Get contract address
ADDRESS=$2

echo "Verifying $CONTRACT at address $ADDRESS"

echo "Enter constructor signature (Enter to skip)"
read CONSTRUCTOR_SIG # e.g. constructor(uint256,address)

if [ -n "$CONSTRUCTOR_SIG" ]
then
    echo "Enter constructor arguments"
    read CONSTRUCTOR_ARGS # e.g. 111111 0x0000000000000000000000000000000000000001
fi

source .env
for i in "${!CHAIN_IDS[@]}"; do
    CHAIN_ID=${CHAIN_IDS[$i]}
    API_KEY=${API_KEYS[$i]}

    if [ -z "$CONSTRUCTOR_SIG" ]; then
        echo "Verifying contract on chain ID $CHAIN_ID with API key $API_KEY without constructor arguments"
        forge verify-contract --chain-id "$CHAIN_ID" "$ADDRESS" "$CONTRACT" --etherscan-api-key "$API_KEY" --watch
    else
        ENCODED_ARGS=$(cast abi-encode "$CONSTRUCTOR_SIG" $CONSTRUCTOR_ARGS)
        echo "Verifying contract on chain ID $CHAIN_ID with API key $API_KEY with constructor arguments"
        forge verify-contract --chain-id "$CHAIN_ID" "$ADDRESS" "$CONTRACT" --constructor-args "$ENCODED_ARGS" --etherscan-api-key "$API_KEY" --watch
    fi

    sleep 60
done
