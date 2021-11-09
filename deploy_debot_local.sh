#!/bin/bash
set -e

DEPLOYMENT_DIR=./deployment
CONTRACT_NAME=ShoppingList
DEBOT_NAME=${1%.*}
NETWORK="${2:-http://127.0.0.1}"

#
# This is TON OS SE giver address, correct it if you use another giver
#
GIVER_ADDRESS=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
CRYSTALS_AMOUNT=10000000000

# Check if tonos-cli installed 
tos=tonos-cli
if $tos --version > /dev/null 2>&1; then
    echo "OK $tos installed locally."
else 
    tos=tonos-cli
    if $tos --version > /dev/null 2>&1; then
        echo "OK $tos installed globally."
    else 
        echo "$tos not found globally or in the current directory. Please install it and rerun script."
    fi
fi


function giver {
    $tos --url $NETWORK call \
         --abi $DEPLOYMENT_DIR/local_giver.abi.json \
         $GIVER_ADDRESS \
         sendGrams "{\"dest\":\"$1\",\"amount\":$CRYSTALS_AMOUNT}" \
         1>/dev/null
}

function get_address {
    echo $(cat $DEPLOYMENT_DIR/$1.log | grep "Raw address:" | cut -d ' ' -f 3)
}

function genaddr {
    $tos genaddr $1.tvc $1.abi.json --genkey $DEPLOYMENT_DIR/$1.keys.json > $DEPLOYMENT_DIR/$1.log
}

function decode {
    $tos decode stateinit $1.tvc --tvc | tail -n +5 > $DEPLOYMENT_DIR/$1.decode.json 2>&1
}

echo "Step 1. Calculating debot address"
genaddr $DEBOT_NAME
DEBOT_ADDRESS=$(get_address $DEBOT_NAME)

echo "Step 2. Sending $CRYSTALS_AMOUNT tokens to address: $DEBOT_ADDRESS"
giver $DEBOT_ADDRESS

echo "Step 3. Deploying contract"
$tos --url $NETWORK deploy $DEBOT_NAME.tvc "{}" \
     --sign $DEPLOYMENT_DIR/$DEBOT_NAME.keys.json \
     --abi $DEBOT_NAME.abi.json 1>/dev/null

DEBOT_ABI=$(cat $DEBOT_NAME.abi.json | xxd -ps -c 20000)

$tos --url $NETWORK call $DEBOT_ADDRESS setABI "{\"dabi\":\"$DEBOT_ABI\"}" \
     --sign $DEPLOYMENT_DIR/$DEBOT_NAME.keys.json \
     --abi $DEBOT_NAME.abi.json \
     1>/dev/null

echo "Step 4. Getting debot info"
$tos --url $NETWORK run \
     --abi $DEBOT_NAME.abi.json \
     $DEBOT_ADDRESS getDebotInfo "{}" > $DEPLOYMENT_DIR/$DEBOT_NAME.info.json

echo "Step 5. Setting contract code to debot"

decode ShoppingList

$tos --url $NETWORK call --abi $DEBOT_NAME.abi.json \
     --sign $DEPLOYMENT_DIR/$DEBOT_NAME.keys.json \
     $DEBOT_ADDRESS setShoppingListCode $DEPLOYMENT_DIR/ShoppingList.decode.json \
     1>/dev/null

echo "Done! Deployed debot with address: $DEBOT_ADDRESS"