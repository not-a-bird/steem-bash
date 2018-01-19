#!/bin/bash

##
# This script fetches the total worth of the specified users and displays it in the style of a stock ticker.

trap "tput cnorm" exit

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

if [ -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their account worth in a ticker."
else
    while true; do
        TICKERINFO=
        for USER in $@ ; do
            TICKERINFO=${TICKERINFO}$(printf "$USER: %'0.2f   " "$(get_bank $USER)")
        done
        echo -ne '\r.'
        tickline "$TICKERINFO"
    done
fi
