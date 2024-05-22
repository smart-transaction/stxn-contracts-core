#!/bin/bash

# Check if at least one argument is passed
if [ $# -lt 1 ]; then
    echo "Usage: $0 <command>"
    exit 1
fi

# Get the contract name
CONTRACT=$1

SCRIPT_NAME="Deploy${CONTRACT}"

SALT=$2

# Get the network
echo "Select Network (local/testnet/mainnet)"
read NETWORK

# TODO: Deploy selected chains
if [ "$NETWORK" = "mainnet" ]; then
   SIGNATURE="deployMainnet()"
elif [ "$NETWORK" = "testnet" ]; then
   SIGNATURE="deployTestnet(uint256)" # TODO: pass counter salt
elif [ "$NETWORK" = "local" ]; then
   SIGNATURE="deployLocal()"
else
   echo "INVALID INPUT"
   exit 1
fi

if [ "$NETWORK" = "testnet" ]
then
    cmd="forge script $SCRIPT_NAME $SALT --sig '$SIGNATURE'"
else
    cmd="forge script $SCRIPT_NAME --sig '$SIGNATURE'"
fi

echo "Broadcast deployment? (y/n)"
read BROADCAST

if [ "$BROADCAST" = "y" ]
then
    cmd="$cmd --broadcast"
fi

# Execute the built command
echo "Executing: $cmd"
DEPLOYMENT=$(eval "$cmd" | grep -oE '0x[[:xdigit:]]{40}' | uniq)

is_valid_ethereum_address() {
  if [[ $1 =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    return 0
  else
    return 1
  fi
}

# Check if DEPLOYMENT is a valid Ethereum address
if ! is_valid_ethereum_address "$DEPLOYMENT"; then
  echo "Deployment Failed!"
  exit 1
fi

if [ $BROADCAST=="y" ]
then
    echo "Verifying deployment at address $DEPLOYMENT"

    echo "Enter constructor signature (Enter to skip)"
    read CONSTRUCTOR_SIG # e.g. constructor(uint256,address)

    source .env

    for i in "${!CHAIN_IDS[@]}"; do
        CHAIN_ID=${CHAIN_IDS[$i]}
        API_KEY=${API_KEYS[$i]}

        if [ -z "$CONSTRUCTOR_SIG" ]; then
            echo "Verifying contract on chain ID $CHAIN_ID with API key $API_KEY without constructor arguments"
            forge verify-contract --chain-id "$CHAIN_ID" "$DEPLOYMENT" "$CONTRACT" --etherscan-api-key "$API_KEY" --watch
        else
            ENCODED_ARGS=$(cast abi-encode "$CONSTRUCTOR_SIG" $CONSTRUCTOR_ARGS)
            echo "Verifying contract on chain ID $CHAIN_ID with API key $API_KEY with constructor arguments"
            forge verify-contract --chain-id "$CHAIN_ID" "$DEPLOYMENT" "$CONTRACT" --constructor-args "$ENCODED_ARGS" --etherscan-api-key "$API_KEY" --watch
        fi
    done
fi
