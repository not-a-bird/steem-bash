#!/bin/bash

##
# This script fetches the total worth of the specified users and displays it in the style of a stock ticker.

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

##
# Get a ticker of various account $$ information.
get_ticker_string(){
    local WHOM=${1}
    local WHERE=$(mktemp)
    local SUCCESS=0
    local CURRENCY=${2:-USD}

    if rpc_get_accounts "${WHOM}" | jq '.[0]' > "${WHERE}" ; then
        local PRICES=$(get_prices "STEEM SBD" "${CURRENCY}")
        local STEEMV=$(jq ".STEEM.${CURRENCY}" <<< $PRICES)
        local SBDV=$(jq ".SBD.${CURRENCY}" <<< $PRICES)
        local BALANCE=$(jq '.balance' < "${WHERE}" | cut -f2 -d'"' |  cut -f1 -d" ")
        local SBD_BALANCE=$(jq '.sbd_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local VESTING_SHARES=$(jq '.vesting_shares' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_SAVINGS=$(jq '.savings_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_POWER=$(get_steempower_for_vests "$VESTING_SHARES")
        local STEEMS=$(math "${STEEM_POWER}+${STEEM_SAVINGS}+${BALANCE}" 2)
        local BANK=$(math "(${BALANCE}+${STEEM_POWER}+${STEEM_SAVINGS}) * ${STEEMV} + ${SBD_BALANCE} * ${SBDV}")
        echo "${WHOM}: ${BANK} [SBD: ${SBD_BALANCE} (${CURRENCY}: $(math "${SBDV}*${SBD_BALANCE}" 2)) STEEM: ${STEEMS} (${CURRENCY}: $(math "${STEEMS} * ${STEEMV}" 2)]"
    fi
}

if [ -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their account worth in a ticker."
else
    tput civis
    while true; do
        echo -ne '\r.'
        for USER in $@ ; do
            TICKERINFO=${TICKERINFO}"$(get_ticker_string "${USER}")    "
        done
        COL=$(tput cols)
        SPACES=$(printf "%$((COL-2))s" " ")
        TICKERINFO="${SPACES} ${TICKERINFO}"
        for ((i=2;i<${#TICKERINFO};i++)); do
            echo -ne "\r" "$(cut -c$i-$((i+COL-3)) <<< $TICKERINFO)"
            sleep 0.25
        done
    done
    tput cnorm
fi
