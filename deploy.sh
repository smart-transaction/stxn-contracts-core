#!/bin/bash
# Execute this scipt with: ./deploy.sh <CONTRACT NAME> <SALT(only for testnet)>

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
echo "Select Network (mainnet/testnet)"
read NETWORK

if [ "$NETWORK" = "mainnet" ]; then
   SIGNATURE="deployMainnet()"
else
   SIGNATURE="deployLestnet(uint256)"
fi

if [ "$NETWORK" = "mainnet" ]
then
    cmd="forge script $SCRIPT_NAME --sig '$SIGNATURE'"
else
    cmd="forge script $SCRIPT_NAME $SALT --sig '$SIGNATURE'"
fi

echo "Broadcast deployment? (y/n)"
read BROADCAST

if [ "$BROADCAST" = "y" ]
then
    cmd="$cmd --broadcast"
fi

# Execute the built command
echo "Executing: $cmd"
eval "$cmd"
