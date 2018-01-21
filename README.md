# STEEM-BASH

This is a project to create a useful set of functions that can be used in Bash
scripts to allow accessing elements of the STEEM blockchain.  Where possible,
native bash or very commonly available unix utilities (wget, sed, awk, grep, cut,
etc) will be used to fetch and manipulate STEEM blockchain content for display.

This project makes use of only the most common Unix utilities (wget, grep, cut,
etc) to fetch and manipulate content from the STEEM blockchain for use in Bash
scripts.  The current features include fetching user profiles, fetching
specific data from those profiles, and calculating the worth of a user's wallet
in USD.  This calculation uses values from cryptocompare, steemd, and
steemit.com.

# Using

Import `functions.sh` in your script and then call any functions you want.

## Examples

There are some example scripts, they all take a minimum, one or more account names.

* `worth.sh` - original one-shot example for fetching account value
* `balances.sh` - an uber example ticker or one-shot script

The `worth.sh` script is a very basic example that only supports a user name.

Example:

    $ worth.sh not-a-bird
    1577.120

The `balances.sh` supports more options and multiple user names.

    Usage: 
        balances.sh [-b] [-c CURRENCY] [-e RPC_ENDPOINT] [-s] [-t] [-w] [-p] [-h] <USER> [USER ...]"

    Get and display balance information about the specified user.

    - b show balances (sbd, steem, savings) [default when no options specified]
    - c CURRENCY (default is USD)
    - e specify service node endpoint
    - h show (this) help
    - p include pending payouts in output
    - s include SP in output
    - t enable stock ticker output
    - w include total account worth in output

Examples:

    $ balances.sh -b not-a-bird
    not-a-bird  1.899 STEEM 2.027 SBD 1.000 Savings

    $ balances.sh -w not-a-bird
    not-a-bird  worth: 1,157.77 USD

    $ balances.sh -c LTC -w not-a-bird
    not-a-bird  worth: 6.00 LTC

    $ balances.sh -p not-a-bird
    not-a-bird  pending payout: 248.86 SBD (USD: 1072.587)

    $ balances.sh -p -c BTC not-a-bird ned
    not-a-bird  pending payout: 248.87 SBD (BTC: 0.095)
    ned  pending payout: 0.00 SBD (BTC: 0.000)

    $ balances.sh -bpw -c BTC not-a-bird ned
    not-a-bird  worth: 0.10 BTC 1.899 STEEM 2.027 SBD 1.000 Savings pending payout: 248.88 SBD (BTC: 0.094)
    ned  worth: 1,452.40 BTC 141871.305 STEEM 5743.288 SBD 0.000 Savings pending payout: 0.00 SBD (BTC: 0.000)

The `posts.sh` script can be used (among other purposes) to generate backlinks:

    $ ./posts.sh -b -t fiction not-a-bird
    [Sorcery - 16](/fiction/@not-a-bird/sorcery-16)
    [Sorcery - 15](/fiction/@not-a-bird/sorcery-15)
    [5 Minute Freewrite: Friday - Prompt: corn](/freewrite/@not-a-bird/5-minute-freewrite-friday-prompt-corn)
    [Sorcery - 14](/fiction/@not-a-bird/sorcery-14)

And it supports (amone other features) tag filtering for exclusion:

    $  ./posts.sh -b -t fiction -e freewrite not-a-bird
    [Sorcery - 16](/fiction/@not-a-bird/sorcery-16)
    [Sorcery - 15](/fiction/@not-a-bird/sorcery-15)
    [Sorcery - 14](/fiction/@not-a-bird/sorcery-14)


# Additional Functionality

The project is organized as a single `functions.sh` script that can be sourced
from other scripts, and then the functions within it can be invoked directly.

Current functionality:

 * `get_profile`
Gets the specified user's profile as JSON.

 * `get_bank` (Updated to use the JSON RPC calls)
Gets the value of the specified user's wallet, including STEEM, SP, SBD, and
savings (but not delegations, since these aren't owned by the user).

 * `get_steem_per_mvest`
Gets the current rate in STEEM for each million vesting shares.  This is useful
in computing the SP for a given user.

 * `get_price`, `get_prices`
Gets the price for a given crypto currency from cryptocompare.com.

 * `get_steempower_for_vests`
Gets the steem power based for an input number of vesting shares.

# RPC Functions

I've added a plethora of Steem RPC functions, traditionally known as the steemd
functions.  For now they're all prefixed with `rpc`.  I hope to make a
friendlier set of functions that perhaps use more logical bash structures, but
we'll see how that unfolds.

Current set of RPC functions:

 * `rpc_invoke()`
 * `rpc_raw()`
 * `rpc_get_account_count()`
 * `rpc_get_account_history()`
 * `rpc_get_account_votes()`
 * `rpc_get_accounts()`
 * `rpc_get_active_votes()`
 * `rpc_get_active_witnesses()`
 * `rpc_get_block()`
 * `rpc_get_chain_properties()`
 * `rpc_get_config()`
 * `rpc_get_content()`
 * `rpc_get_content_replies()`
 * `rpc_get_conversion_requests()`
 * `rpc_get_current_median_history_price()`
 * `rpc_get_discussions_by_active()`
 * `rpc_get_discussions_by_author_before_date()`
 * `rpc_get_discussions_by_cashout()`
 * `rpc_get_expiring_vesting_delegations()`
 * `rpc_get_discussions_by_blog()`
 * `rpc_get_discussions_by_children()`
 * `rpc_get_discussions_by_comments()`
 * `rpc_get_discussions_by_created()`
 * `rpc_get_discussions_by_feed()`
 * `rpc_get_discussions_by_hot()`
 * `rpc_get_discussions_by_payout()`
 * `rpc_get_discussions_by_promoted()`
 * `rpc_get_discussions_by_trending()`
 * `rpc_get_discussions_by_votes()`
 * `rpc_get_discussions_by_payout()`
 * `rpc_get_dynamic_global_properties()`
 * `rpc_get_escrow()`
 * `rpc_get_expiring_vesting_delegtions()`
 * `rpc_get_feed_history()`
 * `rpc_get_hardfork_version()`

# Requirements

Uses the following programs in addition to Bash:

* bc
* grep
* jq
* wget
* zcat
* tac

# Contributing
Fork me!  I'll evaluate pull requests as quickly as I can.

## Mac
I need testers!  The functions and script have only been tested on Ubuntu
17.10.  Hypothetically it should work on other Linux and Unix flavors.  I can
create VMs for testing everything but Mac.

## Testing Frameworks

I'm still looking into testing frameworks that can be used to automate testing
of Bash scripts.  If you know of any good ones, please let me know!

## Contacting Me

The only social network I use it the Steem blockchain.  You can find me on the
Utopian.io Discord server, the steemit.chat server, or even message me directly
or comment on one of my posts and I'll get back to you.

