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

#set -x

##
# On exit make the cursor visible.
cleanup(){
    tput cnorm
}

trap cleanup exit SIGTERM

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
- l display (only) liquid asset values (SBD & STEEM)
- p include pending payouts in output
- s include SP in output
- t enable stock ticker output
- w include total account worth in output
- T time to sleep between ticker line updates
EOF
}

CURRENCY=USD
TIMER=0.25
while getopts ":a:c:e:bhlstT:wp" OPT; do
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
        l )
        LIQUID=yes
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
    while true; do
        if [ ! -z "${TICKER}" ] ; then
            echo -ne '\r.'
        fi
        TICKERINFO=
        for USER in $@ ; do
            TICKERINFO="${TICKERINFO}  ${USER} "
            WHERE=$(rpc_get_accounts "${USER}" | jq '.[0]')
            if [ $? -eq 0 ] ; then
                STEEM_BALANCE=$(jq -r '.balance' <<< "${WHERE}" | cut -f1 -d" ")
                SBD_BALANCE=$(jq -r '.sbd_balance' <<< "${WHERE}" | cut -f1 -d" ")
                VESTING_SHARES=$(jq -r '.vesting_shares' <<< "${WHERE}" | cut -f1 -d" ")
                STEEM_SAVINGS=$(jq -r '.savings_balance' <<< "${WHERE}" | cut -f1 -d" ")
                STEEM_POWER=$(get_steempower_for_vests "$VESTING_SHARES")
                PRICES=$(get_prices "${STEEM_TICKER} ${SBD_TICKER}" "${CURRENCY}")
                SBDV=$(jq ".\"${SBD_TICKER}\".\"${CURRENCY}\"" <<< $PRICES)
                if [ ! -z "${WORTH}" ] ; then
                    STEEMV=$(jq ".\"${STEEM_TICKER}\".\"${CURRENCY}\"" <<< $PRICES)
                    if [ -z "${LIQUID}" ] ; then
                        printf -v BANKFMT "%'0.2f" $(math "${STEEM_BALANCE}*${STEEMV}+${SBD_BALANCE}*${SBDV}+${STEEM_POWER}*${STEEMV}")
                        TICKERINFO="${TICKERINFO} worth: ${BANKFMT} ${CURRENCY}"
                    else
                        printf -v BANKFMT "%'0.2f" $(math "${STEEM_BALANCE}*${STEEMV}+${SBD_BALANCE}*${SBDV}")
                        TICKERINFO="${TICKERINFO} liquid worth: ${BANKFMT} ${CURRENCY}"
                    fi
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
                TICKERINFO="${TICKERINFO} [[${COIN}: $(jq ".\"${COIN}\".\"${CURRENCY}\"" <<< ${ALTPRICES})]] "
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
