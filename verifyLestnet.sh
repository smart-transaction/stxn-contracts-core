#!/bin/bash

# Get the contract name
CONTRACT=$1

# Get contract address
ADDRESS=$2

echo "Enter constructor signature (Enter to skip)"
read CONSTRUCTOR_SIG # e.g. constructor(uint256,address)

if [ -n "$CONSTRUCTOR_SIG" ]
then
    echo "Enter constructor arguments"
    read CONSTRUCTOR_ARGS # e.g. 111111 0x0000000000000000000000000000000000000001
fi

source .env

if [ -z "$CONSTRUCTOR_SIG" ]; then
    forge verify-contract --rpc-url $LESTNET_RPC $ADDRESS $CONTRACT --verifier blockscout --verifier-url $LESTNET_API_KEY
else
    ENCODED_ARGS=$(cast abi-encode "$CONSTRUCTOR_SIG" $CONSTRUCTOR_ARGS)
    forge verify-contract --rpc-url $LESTNET_RPC "$ADDRESS" "$CONTRACT" --constructor-args "$ENCODED_ARGS" --verifier blockscout --verifier-url $LESTNET_API_KEY
fi