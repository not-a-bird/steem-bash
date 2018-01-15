#!/bin/bash

##
# Generic functions and functions for interacting with a Steem.

##
# Display a message on standard error
error(){
    echo "$@" >&2
}

##
# Do a wget against the target, provide the document to submit on standard in.
get_profile(){
    local WHOM=${1}
    wget "https://steemit.com/@${WHOM}.json" -O - 2>/dev/null l| zcat
}

##
# Get the value of the specified user's STEEM assets in the specified (or USD) currency.
get_bank(){
    local WHOM=${1}
    local WHERE=$(mktemp)
    local SUCCESS=0
    local CURRENCY=${2:-USD}

    if get_profile "${WHOM}" > "${WHERE}" ; then
        local STEEMV=$(wget "https://min-api.cryptocompare.com/data/price?fsym=STEEM&tsyms=${CURRENCY}" -O - 2>/dev/null | jq '.USD')
        local SBDV=$(wget "https://min-api.cryptocompare.com/data/price?fsym=SBD&tsyms=${CURRENCY}" -O - 2>/dev/null | jq '.USD')
        local BALANCE=$(jq '.user.balance' < "${WHERE}" | cut -f2 -d'"' |  cut -f1 -d" ")
        local SBD_BALANCE=$(jq '.user.sbd_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local VESTING_SHARES=$(jq '.user.vesting_shares' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_SAVINGS=$(jq '.user.savings_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_PER_MVEST=$(wget "https://steemd.com" -O - 2>/dev/null | grep -o '<samp>steem_per_mvests</samp></th></tr><tr><td><i>[0-9]\+\.[0-9]\+</i>' | grep -o '[0-9]\+\.[0-9]\+')
        local STEEM_POWER=$(echo "scale=3; ${VESTING_SHARES}*${STEEM_PER_MVEST}/1000000.0" | bc -l)
        local BANK=$(echo "scale=3; (${BALANCE}+${STEEM_POWER}+${STEEM_SAVINGS}) * ${STEEMV} + ${SBD_BALANCE} * ${SBDV}" | bc -l)
        echo "${BANK}"
        rm "${WHERE}"
    else
        rm "${WHERE}"
        SUCCESS=-1
    fi

    return ${SUCCESS}
}

get_steem_per_mvest(){
    wget "https://steemd.com" -O - 2>/dev/null | grep -o '<samp>steem_per_mvests</samp></th></tr><tr><td><i>[0-9]\+\.[0-9]\+</i>' | grep -o '[0-9]\+\.[0-9]\+'
}
