#!/bin/bash

##
# This script fetches the total worth of the specified users and displays it in the style of a stock ticker.

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

if [ -z "${1}" ] ; then
    error "No user specified!  Specify a user (without the @) to see the total worth of their account!"
else
    tput civis
    while true; do
        TICKERINFO="      "
        for USER in $@ ; do
            TICKERINFO=${TICKERINFO}$(echo "$USER: $(get_bank $USER)      ")
        done
        for ((i=1;i<${#TICKERINFO};i++)); do
            echo -ne "\r" "$(cut -c$i- <<< $TICKERINFO)"
            sleep 0.25
        done
    done
    tput cnorm
fi
