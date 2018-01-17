#!/bin/bash

##
# Generic functions and functions for interacting with Steem.

##
#     error <message>
#
# Display a message on standard error.
error(){
    echo "$@" >&2
}

##
#     math <problem>
#
# A general purpose function for shelling out to do math.  Assumes a scale of 3
# (significant digits).
math(){
    local PROBLEM=${1}
    local SCALE=${2:-3}
    printf "%.${SCALE}f" $(echo "$PROBLEM" | bc -l )
}

##
#     get_steem_per_mvest
#
# Scrape steemd for the value in steem of a million vesting shares.
get_steem_per_mvest(){
    local RESULT=$(mktemp)
    rpc_get_dynamic_global_properties > "${RESULT}"
    local TOTAL_VESTING_FUND_STEEM=$(jq ".total_vesting_fund_steem" < "${RESULT}" | cut -f2 -d'"' | cut -f1 -d' ')
    local TOTAL_VESTING_SHARES=$(jq ".total_vesting_shares" < "${RESULT}" | cut -f2 -d'"' | cut -f1 -d' ')
    echo $(math "${TOTAL_VESTING_FUND_STEEM}/${TOTAL_VESTING_SHARES}*1000000")
    rm "${RESULT}"
}

##
#    get_steem_per_vest
# Get the amount of steem per vesting share, this avoids multiplying by a
# million so that the calculate of steempower_for_vests wont need to do extra
# math.
get_steem_per_vest(){
    local RESULT=$(mktemp)
    rpc_get_dynamic_global_properties > "${RESULT}"
    local TOTAL_VESTING_FUND_STEEM=$(jq ".total_vesting_fund_steem" < "${RESULT}" | cut -f2 -d'"' | cut -f1 -d' ')
    local TOTAL_VESTING_SHARES=$(jq ".total_vesting_shares" < "${RESULT}" | cut -f2 -d'"' | cut -f1 -d' ')
    echo $(math "${TOTAL_VESTING_FUND_STEEM}/${TOTAL_VESTING_SHARES}" 10)
    rm "${RESULT}"
}

##
#     get_price <TOKEN> [CURRENCY]
#
# Ask cryptocompare.com for the price of TOKEN in CURRENCY.
# The currency defaults to USD.
get_price(){
    local TOKEN=${1}
    local CURRENCY=${2:-USD}
    wget "https://min-api.cryptocompare.com/data/price?fsym=${TOKEN}&tsyms=${CURRENCY}" -O - 2>/dev/null | jq ".${CURRENCY}"
}

##
#    get_prices <TOKEN ...> [CURRENCY]
# Ask cryptocompare.com for the prices of multiple tokens in CURRENCY.
get_prices(){
    local TOKENS=${1}
    local CURRENCY=${2:-USD}
    TOKENS=$(sed 's/ /,/g' <<< $TOKENS)
    wget "https://min-api.cryptocompare.com/data/pricemulti?fsyms=${TOKENS}&tsyms=${CURRENCY}" -O - 2>/dev/null
}

##
#     get_steempower_for_vests <VESTS>
#
# Calculates steem power provided a number of vesting shares.
get_steempower_for_vests(){
    local VESTS=${1}
    local STEEM_PER_VEST=$(get_steem_per_vest)
    local STEEM_POWER=$(math "${VESTS}*${STEEM_PER_VEST}" 10)
    echo "${STEEM_POWER}"
}

##
#     get_profile <username>
#
# Do a wget against the target, provide the document to submit on standard in.
get_profile(){
    local WHOM=${1}
    wget "https://steemit.com/@${WHOM}.json" -O - 2>/dev/null | zcat
}

##
#     get_bank <username> [currency]
#
# Get the value of the specified user's STEEM assets in the specified currency
# (defaults to USD).
get_bank(){
    local WHOM=${1}
    local WHERE=$(mktemp)
    local SUCCESS=0
    local CURRENCY=${2:-USD}

    if rpc_get_accounts "${WHOM}" | jq '.[0]' > "${WHERE}" ; then
        local PRICES=$(get_prices "STEEM SBD" "${CURRENCY}")
        local STEEMV=$(jq ".STEEM.${CURRENCY}" <<< $PRICES)
        local SBDV=$(jq ".SBD.${CURRENCY}" <<< $PRICES)
        local BALANCE=$(jq '.balance' < "${WHERE}" | cut -f2 -d'"' |  cut -f1 -d" ")
        local SBD_BALANCE=$(jq '.sbd_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local VESTING_SHARES=$(jq '.vesting_shares' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_SAVINGS=$(jq '.savings_balance' < "${WHERE}" | cut -f2 -d'"'| cut -f1 -d" ")
        local STEEM_POWER=$(get_steempower_for_vests "$VESTING_SHARES")
        local BANK=$(math "(${BALANCE}+${STEEM_POWER}+${STEEM_SAVINGS}) * ${STEEMV} + ${SBD_BALANCE} * ${SBDV}")
        echo "${BANK}"
    else
        SUCCESS=-1
    fi

    rm "${WHERE}"
    return ${SUCCESS}
}

##
# RPC Functionsa
# These are cobbled togethe from the python api as I'm not sure where the exact documentation is located (yet).
# They all output JSON as their result.
# Do distinguish RPC functions from other functions, all RPC functions begin with rpc_
RPC_ENDPOINT="https://steemd.privex.io"

##
#     rpc_invoke <method> <args> [endpoint]
# Invokes the specified RPC method giving it the provided arguments and going against the provided RPC endpoint.  Defaults to $RPC_ENDPOINT global.
rpc_invoke(){
    local METHOD=${1}
    local ARGS=${2:-null}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    local DATA="{ \"jsonrpc\": \"2.0\", \"method\": \"${METHOD}\", \"params\": [${ARGS},] \"id\": 1 }"
    wget --method=PUT --body-data "${DATA}"  -O - "${ENDPOINT}" 2>/dev/null | jq '.result'
}

##
# Like rpc_invoke, but doesn't pull out the result element.
rpc_raw(){
    local METHOD=${1}
    local ARGS=${2:-null}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    local DATA="{ \"jsonrpc\": \"2.0\", \"method\": \"${METHOD}\", \"params\": [${ARGS},] \"id\": 1 }"
    wget --method=PUT --body-data "${DATA}"  -O - "${ENDPOINT}" 2>/dev/null
}

#
#    rpc_get_account_count [ENDPOINT]
# Gets the total number of accounts currently registered.  Specify an optional
# endpoint for where the service should be invoked.
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# How many accounts are currently registered on STEEM?
rpc_get_account_count(){
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_account_count "" "${ENDPOINT}"
}

##
#     rpc_get_account_history <account> <index_from> <limit> [ENDPOINT]
#
# Get the last `limit` number of operations, beginning with operation `index_from`
# for the specified account name.
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# History of all operations for a given account.
#
#     Parameters:
#         account (str) – STEEM username that we are looking up.
#         index_from (int) – The highest database index we take as a starting point.
#         limit (int) – How many items are we interested in.
#     Returns:	
#       List of operations.
#
#     Return type:	
#       list
rpc_get_account_history(){
    local ACCOUNT=${1}
    local INDEX_FROM=${2}
    local LIMIT=${3}
    local ENDPOINT=${4:-${RPC_ENDPOINT}}
    rpc_invoke get_account_history "${ACCOUNT} $INDEX_FROM $LIMIT" "${ENDPOINT}"
}

##
#    rpc_get_account_votes <account_name> [ENDPOINT]
#
# Gets all votes the account has ever made.
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# All votes the given account ever made.
#
#     Parameters:
#         account (str) – STEEM username that we are looking up.
#     Returns:
#         List of votes.
#     Return type:i
#         list
rpc_get_account_votes(){
    local WHOM=${1}
    local ENDPOINT=${2:-${RPC_ENDPOINT}}
    rpc_invoke get_account_votes "${WHOM}" "${ENDPOINT}"
}

##
#    rpc_get_accounts <account ...> [ENDPOINT]
#
# Users should be a space separated list of user names.
#
# For example:
#     rpc_get_accounts "not-a-bird not-a-gamer"
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# Lookup account information such as user profile, public keys, balances, etc.
#
#     Parameters:
#         account (str) – STEEM username that we are looking up.
#     Returns:
#         Account information.
#     Return type:
#         dict
#
rpc_get_accounts(){
    local ARGS=${@}
    rpc_invoke get_accounts "$(jq -c -n -M --arg v "${ARGS}" '($v|split(" "))')"
}

##
#    rpc_get_active_votes <account> <permlink> [ENDPOINT]
#
# Gets the active votes for a given post.  The permlink here is usually the stuff in the URL that comes *after* the user name.
#
# For example:
#     rpc_get_account_votes not-a-bird steem-bash
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# Get all votes for the given post.
#
#      Parameters:
#          author (str) – OP’s STEEM username.
#          permlink (str) – Post identifier following the username. It looks like slug-ified title.
#      Returns:
#          List of votes.
#      Return type:
#          list
#
rpc_get_active_votes(){
    local ACCOUNT=${1}
    local PERMLINK=${2}
    local ENDPOINT=${3:${RPC_ENDPOINT}}
    rpc_invoke get_active_votes "\"${ACCOUNT}\" \"${PERMLINK}\"" "${ENDPOINT}"
}

##
#    rpc_get_active_witnesses [ENDPOINT]
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# Get a list of currently active witnesses.
rpc_get_active_witnesses(){
    local ENDPOINT=${1:-${RPC_ENDPOINT}}
    rpc_invoke get_active_witnesses "${ENDPOINT}"
}

##
#    rpc_get_block <number> [ENDPOINT]
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
#
#    get_block(block_num: int)
#
# Get the full block, transactions and all, given a block number.
#
#    Parameters:
#        block_num (int) – Block number.
#    Returns:
#        Block in a JSON compatible format.
#    Return type:
#        dict
rpc_get_block(){
    local NUMBER=${1}
    local ENDPOINT=${2:-${RPC_ENDPOINT}}
    rpc_invoke get_block "${NUMBER}" "${ENDPOINT}"
}

##
#    rpc_get_block_header <number> [ENDPOINT]
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# Get witness elected chain properties.
rpc_get_chain_properties(){
    local ENDPOINT=${1:-${RPC_ENDPOINT}}
    rpc_invoke get_chain_properties '' "${ENDPOINT}"
}

##
#    rpc_get_config <number> [ENDPOINT]
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# Get internal chain configuration.
rpc_get_config(){
    local ENDPOINT=${1:-${RPC_ENDPOINT}}
    rpc_invoke get_config '' "${ENDPOINT}"
}

##
#    rpc_get_content <author> <permlink> [ENDPOINT]
#
# Gets the latest version of a given post/comment.
# For example: rpc_get_content not-a-bird steem-bash
rpc_get_content(){
    local ACCOUNT=${1}
    local PERMLINK=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_content "\"${ACCOUNT}\" \"${PERMLINK}\"" "${ENDPOINT}"
}

##
#    rpc_get_content_replies <author> <permlink> [ENDPOINT]
#
# Gets the replies of a given post/comment.
# For example: rpc_get_content_replies not-a-bird steem-bash
rpc_get_content_replies(){
    local ACCOUNT=${1}
    local PERMLINK=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_content_replies "\"${ACCOUNT}\" \"${PERMLINK}\"" "${ENDPOINT}"
}

##
#    rpc_get_conversion_requests <user> [ENDPOINT]
rpc_get_conversion_requests(){
    local ACCOUNT=${1}
    local ENDPOINT=${2:-${RPC_ENDPOINT}}
    rpc_invoke get_conversion_requests "\"${ACCOUNT}\"" "${ENDPOINT}"
}

##
#    rpc_get_current_median_history_price [ENDPOINT]
#
# Original documentation from [web](http://steem.readthedocs.io/en/latest/steem.html):
# Get the average STEEM/SBD price.
#
# This price is based on moving average of witness reported price feeds.
rpc_get_current_median_history_price(){
    local ENDPOINT=${1:-${RPC_ENDPOINT}}
    rpc_invoke get_current_median_history_price "${ENDPOINT}"
}

##
#    rpc_get_discussions_by_active <LIMIT> <TAG> <TRUNCATE> [ENDPOINT]
#  You can pass empty strings for LIMIT and TRUNCATE, they will default to 10
#  and 0.  A value of 0 for truncate means to return the entire post body.
rpc_get_discussions_by_active(){
    local LIMIT=${1:-10}
    local TAG=${2}
    local TRUNCATE=${3:-0}
    local ENDPOINT=${4:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_active "{ \"limit\": ${LIMIT}, \"tag\": \"${TAG}\", \"truncate_body\": $TRUNCATE }" "${ENDPOINT}"
}

##
#    rpc_get_discussions_by_author_before_date <AUTHOR> <PERMLINK> <DATE> <LIMIT>
# Gets top level posts by the specified author before the specified date.  It's
# unclear how the permlink effects it, but it must be valid.  The date field
# accepts at least the format "2018-01-17T01:12:01".  Limit defaults to zero.
rpc_get_discussions_by_author_before_date(){
    local AUTHOR=${1}
    local PERMLINK=${2}
    local DATE=${3}
    local LIMIT=${4:-10}
    local ENDPOINT=${5:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_author_before_date "\"${AUTHOR}\", \"${PERMLINK}\", \"${DATE}\", ${LIMIT}" "${ENDPOINT}"
}

##
#     rpc_get_discussions_by_cashout <TAG> <LIMIT> [ENDPOINT]
#
# FIXME: Gets the top level posts by a query object, which is confusing because
# the docs say otherwise.
rpc_get_discussions_by_cashout(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_cashout  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}

##
#     rpc_get_expiring_vesting_delegations <account> <date> <limit> [ENDPOINT]
rpc_get_expiring_vesting_delegations(){
    local ACCOUNT=${1}
    local DATE=${2}
    local LIMIT=${3}
    local ENDPOINT=${4:-${RPC_ENDPOINT}}
    rpc_invoke get_expiring_vesting_delegations "\"${ACCOUNT}\", \"${DATE}\", ${LIMIT}" "${ENDPOINT}"
}

##
#    rpc_get_discussions_by_blog
rpc_get_discussions_by_blog(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_blog  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_children
rpc_get_discussions_by_children(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_children  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_comments
rpc_get_discussions_by_comments(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_comments  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_created
rpc_get_discussions_by_created(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_created  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_feed
rpc_get_discussions_by_feed(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_feed  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_hot
rpc_get_discussions_by_hot(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_hot  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_payout
rpc_get_discussions_by_payout(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_payout  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_promoted
rpc_get_discussions_by_promoted(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_promoted  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_trending
rpc_get_discussions_by_trending(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_trending  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_votes
rpc_get_discussions_by_votes(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_votes  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}
##
#    rpc_get_discussions_by_payout
rpc_get_discussions_by_payout(){
    local TAG=${1}
    local LIMIT=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_discussions_by_payout  "{ \"tag\": \"${TAG}\", \"limit\": \"${LIMIT}\" }" "${ENDPOINT}"
}

##
# TODO:
#             "cancel_all_subscriptions": 3, (?)
#             "get_account_bandwidth": 45, (what is the account type field?)
#             "get_account_references": 35, (needs to be refactored for steem?)
#             "get_comment_discussions_by_payout": 8, (arguments?)

##
#    get_dynamic_global_properties [ENDPOINT]
# Fetches a number of statistics:
#  {
#    "id": 0,
#    "head_block_number": 19046204,
#    "head_block_id": "01229f3cb9a0f793fd358c038f0e4282accfbdc8",
#    "time": "2018-01-17T03:39:03",
#    "current_witness": "thecryptodrive",
#    "total_pow": 514415,
#    "num_pow_witnesses": 172,
#    "virtual_supply": "263884106.823 STEEM",
#    "current_supply": "262777204.387 STEEM",
#    "confidential_supply": "0.000 STEEM",
#    "current_sbd_supply": "6339230.254 SBD",
#    "confidential_sbd_supply": "0.000 SBD",
#    "total_vesting_fund_steem": "197564777.341 STEEM",
#    "total_vesting_shares": "404524405665.394862 VESTS",
#    "total_reward_fund_steem": "0.000 STEEM",
#    "total_reward_shares2": "0",
#    "pending_rewarded_vesting_shares": "277879180.161400 VESTS",
#    "pending_rewarded_vesting_steem": "134993.008 STEEM",
#    "sbd_interest_rate": 0,
#    "sbd_print_rate": 10000,
#    "average_block_size": 11604,
#    "maximum_block_size": 65536,
#    "current_aslot": 19108381,
#    "recent_slots_filled": "340282366920938463463374607431768211455",
#    "participation_count": 128,
#    "last_irreversible_block_num": 19046187,
#    "max_virtual_bandwidth": "5152702464000000000",
#    "current_reserve_ratio": 390,
#    "vote_power_reserve_rate": 10
#  }
rpc_get_dynamic_global_properties(){
    local ENDPOINT=${1:-${RPC_ENDPOINT}}
    rpc_invoke get_dynamic_global_properties
}

##
#    get_escrow <account> <id> [ENDPOINT]
rpc_get_escrow(){
    local ACCOUNT=${1}
    local ID=${2}
    local ENDPOINT=${3:-${RPC_ENDPOINT}}
    rpc_invoke get_escrow "\"${ACCOUNT}\", ${ID}" "${ENDPOINT}"
}

##
#     rpc_get_expiring_vesting_delegtion <account> <start> <limit>
rpc_get_expiring_vesting_delegtions(){
    local ACCOUNT=${1}
    local START=${2}
    local LIMIT=${3}
    local ENDPOINT=${4:-${RPC_ENDPOINT}}
    rpc_invoke get_expiring_vesting_delegations "\"${ACCOUNT}\", \"${START}\", 10" "${ENDPOINT}"
}

##
#     rpc_get_feed_history [ENDPOINT]
rpc_get_feed_history(){
    local ENDPOINT=${1:-${RPC_ENDPOINT}}
    rpc_invoke get_feed_history
}
##
#     rpc_get_hardfork_version [ENDPOINT]
rpc_get_hardfork_version(){
    local ENDPOINT=${1:-${RPC_ENDPOINT}}
    rpc_invoke get_hardfork_version
}



#             "get_key_references": 33, (deprecated, use ... soemthing else...)
#             "get_liquidity_queue": 52,
#             "get_miner_queue": 71,
#             "get_next_scheduled_hardfork": 31,
#             "get_open_orders": 51,
#             "get_ops_in_block": 22,
#             "get_order_book": 50,
#             "get_owner_history": 41,
#             "get_post_discussions_by_payout": 7,
#             "get_potential_signatures": 56,
#             "get_recovery_request": 42,
#             "get_replies_by_last_update": 64,
#             "get_required_signatures": 55,
#             "get_reward_fund": 32,
#             "get_savings_withdraw_from": 46,
#             "get_savings_withdraw_to": 47,
#             "get_state": 23,
#             "get_tags_used_by_author": 5,
#             "get_transaction": 54,
#             "get_transaction_hex": 53,
#             "get_trending_tags": 4,
#             "get_vesting_delegations": 48,
#             "get_withdraw_routes": 44,
#             "get_witness_by_account": 66,
#             "get_witness_count": 69,
#             "get_witness_schedule": 29,
#             "get_witnesses": 65,
#             "get_witnesses_by_vote": 67,
#             "lookup_account_names": 36,
#             "lookup_accounts": 37,
#             "lookup_witness_accounts": 68,
#             "set_block_applied_callback": 2,
#             "set_pending_transaction_callback": 1,
#             "set_subscribe_callback": 0,
#             "verify_account_authority": 58,
#             "verify_authority": 57





