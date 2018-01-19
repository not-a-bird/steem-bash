#!/bin/bash

trap "tput cnorm" exit

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

while getopts ":bhstwp" OPT; do
    case "${OPT}" in
        b )
        BALANCE=YES
        ;;
        s )
        SP=YES
        ;;
        t )
        TICKER=YES
        ;;
        w )
        WORTH=YES
        ;;
        p )
        PENDING=YES
        ;;
        *) cat << EOF
           
Usage: 
    ${0} [-s] [-t] [-w] [-p] [-h]"

- b balances
- t enable stock ticker output
- w include total account worth in output
- p include pending payouts in output
- s include SP in output
- h show (this) help
EOF
            exit
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their account worth in a ticker."
else
    while true; do
        if [ ! -z "${TICKER}" ] ; then
            echo -ne '\r.'
        fi
        TICKERINFO=
        for USER in $@ ; do
            TICKERINFO="${TICKERINFO}${USER}: "
            if [ ! -z "${WORTH}" ] ; then 
                TICKERINFO="${TICKERINFO} worth: $(get_bank $USER) ${CURRENCY}"
            fi
            if [ ! -z "${BALANCE}" ] ; then
                TICKERINFO="${TICKERINFO} $(get_sbd "${USER}")"
                TICKERINFO="${TICKERINFO} $(get_steem "${USER}")"
            fi
            if [ ! -z "${SP}" ] ; then
                SP=$(get_sp "${USER}")
                TICKERINFO="${TICKERINFO} $(get_sp "${USER}") SP"
            fi
            if [ ! -z "${PENDING}" ] ; then
                PENDING=$(get_payout "${USER}")
                TICKERINFO="${TICKERINFO} pending payouts: ${PENDING} SBD "
            fi
            if [ -z "${TICKER}" ] ; then
                printf -v TICKERINFO "%s\n" "${TICKERINFO}"
            fi
        done
        if [ ! -z "${TICKER}" ] ; then
            tickline "${TICKERINFO}"
        else
            printf "${TICKERINFO}"
            exit 0
        fi
    done
fi
