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
echo "Select Network (local/testnet/mainnet)"
read NETWORK

# TODO: Deploy selected chains
if [ "$NETWORK" = "mainnet" ]; then
   SIGNATURE="deployMainnet()"
elif [ "$NETWORK" = "testnet" ]; then
   SIGNATURE="deployTestnet(uint256)"
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
eval "$cmd"
