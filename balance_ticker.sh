#!/bin/bash

##
# This script fetches the total worth of the specified users and displays it in the style of a stock ticker.

trap "tput cnorm" exit

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
        local BANKFMT=$(printf "%'0.2f" "${BANK}")
        echo "${WHOM}: ${BANKFMT} ${CURRENCY} [$(math "${SBDV}*${SBD_BALANCE}" 2) ${CURRENCY} (${SBD_BALANCE} SBD at ${SBDV} ${CURRENCY}) STEEM: $(math "${STEEMS} * ${STEEMV}" 2) ${CURRENCY} (${STEEMS} STEEM at ${STEEMV} ${CURRENCY})]"
    fi
    rm "${WHERE}"
}


if [ -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their account worth in a ticker."
else
    while true; do
        echo -ne '\r.'
        TICKERINFO=
        for USER in $@ ; do
            TICKERINFO=${TICKERINFO}"$(get_ticker_string "${USER}")"
        done
        tickline "${TICKERINFO}"
    done
fi
