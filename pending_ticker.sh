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
            VALUE=$(math "$(rpc_get_discussions_by_author_before_date "${USER}" '' "$(date -Iseconds)" 10 | grep -Po '"pending_payout_value":.*?[^\\]",' |  cut -f2 -d:  | cut -f2 -d'"' | cut -f1 -d' ' | xargs | sed 's/ /+/g' | bc ) * $(get_price SBD)")
            TICKERINFO="${TICKERINFO} ${USER}: ${VALUE}"
        done
        tickline "${TICKERINFO}"
    done
fi
