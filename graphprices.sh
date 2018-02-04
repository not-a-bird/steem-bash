#!/bin/bash

##
# This script uses Gnuplot to create a graph of any coins specified by the
# user.  Starting from the moment it is invoked it updates the coin values
# every thirty seconds.

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

usage(){
    cat << EOF
Usage:
    ${0} [-s SLEEP] [-c CURRENCY] <COIN ...>

Get the values of the specified coins in the specified currencies and then graph them with gnuplot.

- c CURRENCY (default is USD)
- s SLEEP seconds to wait between updates (default is 30)
EOF
}

DATEFMT='%m-%d %H:%M:%S'
CURRENCY=USD
SLEEP=30
while getopts ":c:" OPT; do
    case "${OPT}" in
        c )
        CURRENCY=${OPTARG}
        ;;
        s )
        SLEEP=${OPTARG}
        ;;
        * )
        usage
        exit 0
        ;;
    esac
done

shift $((OPTIND -1))

while [ ${#} -ne 0 ] ; do
    ALTCOIN[${#ALTCOIN[@]}]=${1}
    shift
done
if [ "${#ALTCOIN[@]}" -eq 0 ] ; then
    usage
    exit 1
fi

TEMPFILE=$(mktemp)
trap "rm ${TEMPFILE}" exit

##
# Appends a line of price data to the specified file.
appendline(){
    local ALTCOINS=${1}
    local FILE=${2}
    local CURRENCY=${3}
    local PRICES
    PRICES=$(get_prices "${ALTCOINS}" "${CURRENCY}")
    if [ $? -eq 0 ] ; then
        echo -n "$(date +"${DATEFMT}")" >> "${FILE}"
        for COIN in ${ALTCOINS} ; do
            echo -n "	$(jq -r ".${COIN}.${CURRENCY}" <<< $PRICES)"
        done >> "${FILE}"
        echo >> "${FILE}"
    fi
}

# get initial prices, so file exists
appendline "${ALTCOIN[*]}" "${TEMPFILE}" "${CURRENCY}"

# spawn background task of updating prices
while true ; do
    sleep "${SLEEP}"
    appendline "${ALTCOIN[*]}" "${TEMPFILE}" "${CURRENCY}"
done &
# keep tellilng gnuplot to do stuff with that data
(
echo "set timefmt '"$DATEFMT"'"
echo "set xdata time"
echo "set datafile separator '\t'"
echo 'set format x "%m/%d\n%H:%M:%S"'
while true ; do
cat << EOF
    $(echo -n plot) $(for ((i=0;i<"${#ALTCOIN[@]}";i++)) ; do echo -n " '$TEMPFILE' using 1:$((i+2)) with line title '${ALTCOIN[${i}]}' "; if [ "$((i+1))" -ne "${#ALTCOIN[@]}" ] ; then echo -n ','; fi; done)
    reread
EOF
sleep "${SLEEP}"
done ) | tee >(cat >&2) |  gnuplot

