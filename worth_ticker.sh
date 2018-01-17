#!/bin/bash

##
# This script fetches the total worth of the specified users and displays it in the style of a stock ticker.

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

if [ -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their account worth in a ticker."
else
    tput civis
    while true; do
        for USER in $@ ; do
            TICKERINFO=${TICKERINFO}$(echo "$USER: $(get_bank $USER)   ")
        done
        COL=$(tput cols)
        TICKERINFO="$(printf "%$((COL))s" "${TICKERINFO}")"
        WIDTH=${#TICKERINFO}
        for ((i=2;i<${#TICKERINFO};i++)); do
            echo -ne "\r" "$(cut -c$i-$((COL-1)) <<< $TICKERINFO)"
            sleep 0.25
        done
    done
    tput cnorm
fi
