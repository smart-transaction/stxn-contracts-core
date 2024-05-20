#!/bin/bash

# Check if at least one argument is passed
if [ $# -lt 1 ]; then
    echo "Usage: $0 <command>"
    exit 1
fi

# Get the contract name
CONTRACT=$1
SCRIPT_NAME="Deploy${CONTRACT}"

Get the network
echo "Select Network (local/testnet/mainnet)"
read NETWORK

# TODO: Deploy selected chains
SIGNATURE=""
if [ $NETWORK=="mainnet" ]
then
   SIGNATURE="deployMainnet()"
elif [ $NETWORK=="testnet" ]
then
   SIGNATURE="deployTestnet()" # TODO: pass counter salt
elif [ $NETWORK=="local" ]
then
   SIGNATURE="deployLocal()"
else
   echo "INVALID INPUT"
fi

cmd="forge script $SCRIPT_NAME --sig '$SIGNATURE'"

echo "Broadcast deployment? (y/n)"
read BROADCAST

if [ $BROADCAST=="y" ]
then
    cmd="$cmd --broadcast"
fi

Execute the built command
echo "Executing: $cmd"
DEPLOYMENT=`eval "$cmd" | grep address | awk '{print $3}'`

if [ $BROADCAST=="y" ]
then
    echo "Verifying deployment at address $DEPLOYMENT"

    echo "Enter constructor signature (Enter to skip)"
    read CONSTRUCTOR_SIG # e.g. constructor(uint256,address)

    if [ $CONSTRUCTOR_SIG=='' ]
    then
        forge verify-contract --chain-id 80002 $ADDRESS $CONTRACT --etherscan-api-key PDUCSBD8WKTFI9D9G912A4JXCB7UX7Z98P --watch
        forge verify-contract --chain-id 11155111 $ADDRESS $CONTRACT --etherscan-api-key 3U7ZHP4MYBSV8Y6TQFGX6DHQY54FBY71EE --watch
        forge verify-contract --chain-id 84532 $ADDRESS $CONTRACT --etherscan-api-key 889NH7DM28WJWDWFWRCXITEU9QT6TWG9QQ --watch
        forge verify-contract --chain-id 421614 $ADDRESS $CONTRACT --etherscan-api-key BFCBXE8IYFDCWU4YQ9J7W72RJXBB7ZKQJJ --watch
        forge verify-contract --chain-id 11155420 $ADDRESS $CONTRACT --etherscan-api-key TC3T9FWYY68DCW41EHDZMX52Z6I4T293EB --watch
    else
        echo "Enter constructor args"
        read CONSTRUCTOR_ARGS # e.g. 111111 0x0000000000000000000000000000000000000001

        forge verify-contract --chain-id 80002 $ADDRESS $CONTRACT --constructor-args $(cast abi-encode $CONSTRUCTOR_SIG $CONSTRUCTOR_ARGS) --etherscan-api-key PDUCSBD8WKTFI9D9G912A4JXCB7UX7Z98P --watch
        forge verify-contract --chain-id 11155111 $ADDRESS $CONTRACT --constructor-args $(cast abi-encode $CONSTRUCTOR_SIG $CONSTRUCTOR_ARGS) --etherscan-api-key 3U7ZHP4MYBSV8Y6TQFGX6DHQY54FBY71EE --watch
        forge verify-contract --chain-id 84532 $ADDRESS $CONTRACT --constructor-args $(cast abi-encode $CONSTRUCTOR_SIG $CONSTRUCTOR_ARGS) --etherscan-api-key 889NH7DM28WJWDWFWRCXITEU9QT6TWG9QQ --watch
        forge verify-contract --chain-id 421614 $ADDRESS $CONTRACT --constructor-args $(cast abi-encode $CONSTRUCTOR_SIG $CONSTRUCTOR_ARGS) --etherscan-api-key BFCBXE8IYFDCWU4YQ9J7W72RJXBB7ZKQJJ --watch
        forge verify-contract --chain-id 11155420 $ADDRESS $CONTRACT --constructor-args $(cast abi-encode $CONSTRUCTOR_SIG $CONSTRUCTOR_ARGS) --etherscan-api-key TC3T9FWYY68DCW41EHDZMX52Z6I4T293EB --watch
    fi
fi



