#!/bin/bash

##
# Display account balances and other information.  Optionally as a stock ticker.
# Usage:
#    ${0} [-a COIN] [-b] [-c CURRENCY] [-e RPC_ENDPOINT] [-s] [-t] [-T seconds] [-w] [-p] [-h] [USER ...]"
#
#- a show altcoin value
#- b show balances (sbd, steem, savings) [default when no options specified]
#- c CURRENCY (default is USD)
#- e specify service node endpoint
#- h show (this) help
#- p include pending payouts in output
#- s include SP in output
#- t enable stock ticker output
#- w include total account worth in output
#- T time to sleep between ticker line updates

trap "tput cnorm" exit

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

##
# Display help message.
usage(){
    cat << EOF
Usage:
    ${0} [-a COIN] [-b] [-c CURRENCY] [-e RPC_ENDPOINT] [-s] [-t] [-T seconds] [-w] [-p] [-h] [USER ...]"

Get and display balance information about the specified user.

- a show altcoin value
- b show balances (sbd, steem, savings) [default when no options specified]
- c CURRENCY (default is USD)
- e specify service node endpoint
- h show (this) help
- p include pending payouts in output
- s include SP in output
- t enable stock ticker output
- w include total account worth in output
- T time to sleep between ticker line updates
EOF
}

CURRENCY=USD
TIMER=0.25
while getopts ":a:c:e:bhstwp" OPT; do
    case "${OPT}" in
        a )
        ALTCOIN[${#ALTCOIN[@]}]=${OPTARG}
        ;;
        b )
        BALANCE=YES
        ;;
        c )
        CURRENCY=${OPTARG}
        ;;
        e )
        RPC_ENDPOINT=${OPTARG}
        ;;
        s )
        SP=YES
        ;;
        t )
        TICKER=YES
        ;;
        T )
        TIMER=${OPTARG}
        ;;
        w )
        WORTH=YES
        ;;
        p )
        PENDING=YES
        ;;
        *) usage
            exit
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "${BALANCE}${SP}${WORTH}${PENDING}" ] ; then
    BALANCE=YES
fi

if [ -z "${ALTCOIN[*]}" -a -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their account worth in a ticker."
    error "Or specify an alt coin to view with -a <COIN>"
    usage
else
    WHERE=$(mktemp)
    while true; do
        if [ ! -z "${TICKER}" ] ; then
            echo -ne '\r.'
        fi
        TICKERINFO=
        for USER in $@ ; do
            TICKERINFO="${TICKERINFO}  ${USER} "
            if rpc_get_accounts "${USER}" | jq '.[0]' > "${WHERE}" ; then
                STEEM_BALANCE=$(jq '.balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
                SBD_BALANCE=$(jq '.sbd_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
                VESTING_SHARES=$(jq '.vesting_shares' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
                STEEM_SAVINGS=$(jq '.savings_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
                STEEM_POWER=$(get_steempower_for_vests "$VESTING_SHARES")
                PRICES=$(get_prices "STEEM SBD" "${CURRENCY}")
                SBDV=$(jq ".SBD.${CURRENCY}" <<< $PRICES)
                if [ ! -z "${WORTH}" ] ; then
                    STEEMV=$(jq ".STEEM.${CURRENCY}" <<< $PRICES)
                    printf -v BANKFMT "%'0.2f" $(math "${STEEM_BALANCE}*${STEEMV}+${SBD_BALANCE}*${SBDV}+${STEEM_POWER}*${STEEMV}")
                    TICKERINFO="${TICKERINFO} worth: ${BANKFMT} ${CURRENCY}"
                fi
                if [ ! -z "${BALANCE}" ] ; then
                    TICKERINFO="${TICKERINFO} ${STEEM_BALANCE} STEEM"
                    TICKERINFO="${TICKERINFO} ${SBD_BALANCE} SBD"
                    TICKERINFO="${TICKERINFO} ${STEEM_SAVINGS} Savings "
                fi
                if [ ! -z "${SP}" ] ; then
                    TICKERINFO="${TICKERINFO} ${STEEM_POWER} SP "
                fi
                if [ ! -z "${PENDING}" ] ; then
                    PAYOUT=$(get_payout "${USER}")
                    TICKERINFO="${TICKERINFO} pending payout: ${PAYOUT} SBD (${CURRENCY}: $(math "${SBDV}*${PAYOUT}"))"
                fi
            fi

            if [ -z "${TICKER}" ] ; then
                printf -v TICKERINFO "%s\n" "${TICKERINFO}"
            fi
        done
        if [ "${#ALTCOIN}" -gt 0 ] ; then
            ALTPRICES=$(get_prices "${ALTCOIN[*]}" "${CURRENCY}")
            for COIN in ${ALTCOIN[@]} ; do
                TICKERINFO="${TICKERINFO} [[${COIN}: $(jq ".${COIN}.${CURRENCY}" <<< ${ALTPRICES})]] "
            done
        fi
        if [ ! -z "${TICKER}" ] ; then
            tickline "${TICKERINFO}" "${TIMER}"
        else
            printf "${TICKERINFO}"
            exit 0
        fi
    done
fi
