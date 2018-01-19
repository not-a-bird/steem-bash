#!/bin/bash

##
# This script fetches the pending payouts for the specified user.

trap "tput cnorm" exit

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

if [ -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their pending payout value in a ticker."
else
    while true; do
        echo -ne '\r.'
        TICKERINFO=
        for USER in $@ ; do
            VALUE=$(math "$(get_payout "${USER}") * $(get_price SBD)" 2)
            TICKERINFO="${TICKERINFO} ${USER}: ${VALUE}"
        done
        tickline "${TICKERINFO}"
    done
fi
