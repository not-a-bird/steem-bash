#!/bin/bash

##
# Generic functions and functions for interacting with Steem.

##
#     error <message>
#
# Display a message on standard error.
error(){
    echo "$@" >&2
}

##
#     math <problem>
#
# A general purpose function for shelling out to do math.  Assumes a scale of 3
# (significant digits).
math(){
    local PROBLEM=${1}
    local SCALE=${2:-3}

    echo "scale=${SCALE}; $@" | bc -l
}

##
#     get_steem_per_mvest
#
# Scrape steemd for the value in steem of a million vesting shares.
get_steem_per_mvest(){
    wget "https://steemd.com" -O - 2>/dev/null | grep -o '<samp>steem_per_mvests</samp></th></tr><tr><td><i>[0-9]\+\.[0-9]\+</i>' | grep -o '[0-9]\+\.[0-9]\+'
}

##
#     get_price <TOKEN> [CURRENCY]
#
# Ask cryptocompare.com for the price of TOKEN in CURRENCY.
# The currency defaults to USD.
get_price(){
    local TOKEN=${1}
    local CURRENCY=${2:-USD}
    wget "https://min-api.cryptocompare.com/data/price?fsym=${TOKEN}&tsyms=${CURRENCY}" -O - 2>/dev/null | jq ".${CURRENCY}"
}

##
#     get_steempower_for_vests <VESTS>
#
# Calculates steem power provided a number of vesting shares.
get_steempower_for_vests(){
    local VESTS=${1}
    local STEEM_PER_MVEST=$(get_steem_per_mvest)
    local STEEM_POWER=$(math "${VESTING_SHARES}*${STEEM_PER_MVEST}/1000000.0")
    echo "${STEEM_POWER}"
}

##
#     get_profile <username>
#
# Do a wget against the target, provide the document to submit on standard in.
get_profile(){
    local WHOM=${1}
    wget "https://steemit.com/@${WHOM}.json" -O - 2>/dev/null | zcat
}

##
#     get_bank <username> [currency]
#
# Get the value of the specified user's STEEM assets in the specified currency
# (defaults to USD).
get_bank(){
    local WHOM=${1}
    local WHERE=$(mktemp)
    local SUCCESS=0
    local CURRENCY=${2:-USD}

    if get_profile "${WHOM}" > "${WHERE}" ; then
        local STEEMV=$(get_price STEEM "${CURRENCY}")
        local SBDV=$(get_price SBD "${CURRENCY}")
        local BALANCE=$(jq '.user.balance' < "${WHERE}" | cut -f2 -d'"' |  cut -f1 -d" ")
        local SBD_BALANCE=$(jq '.user.sbd_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local VESTING_SHARES=$(jq '.user.vesting_shares' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_SAVINGS=$(jq '.user.savings_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_POWER=$(get_steempower_for_vests "$VESTING_SHARES")
        local BANK=$(math "(${BALANCE}+${STEEM_POWER}+${STEEM_SAVINGS}) * ${STEEMV} + ${SBD_BALANCE} * ${SBDV}")
        echo "${BANK}"
    else
        SUCCESS=-1
    fi

    rm "${WHERE}"
    return ${SUCCESS}
}
