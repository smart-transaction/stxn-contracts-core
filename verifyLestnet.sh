#!/bin/bash

# Get the contract name
CONTRACT=$1

# Get contract address
ADDRESS=$2

# TODO: Add conditional logic for constructor arguments and make ot modular with other explorers

source .env
forge verify-contract --rpc-url $LESTNET_RPC $ADDRESS $CONTRACT --verifier blockscout --verifier-url $LESTNET_API_KEY
