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

Currently the only exposed functionality is the script for fetching a given
user's wallet value from the command line.  It can be invoked thusly:

    worth.sh [account-name]

And it will produce the value in USD for the specified account name.

For example:

    $ worth.sh not-a-bird
    1577.120

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

