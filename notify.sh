#!/bin/bash

##
# Watch the activity of your (or any) user and create notifications.


WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi
. "${WHEREAMI}"/functions.sh

if ! ps -ef | grep -i notify-osd >/dev/null ; then
    if ! ps -ef | grep -i notification-daeamon >/dev/null; then
        error "If no notification daemon is running there will be no output.  Make sure one is runnnig before you use this script."
    fi
fi

##
#   get_event_count ACCOUNT
#
# Get the latest number of events for the specified account.
get_event_count(){
    local WHOM=${1}
    local COUNT
    local OUTPUT
    OUTPUT=$(rpc_get_account_history "${WHOM}"  -1 0)
    SUCCESS=$?
    if [ $SUCCESS -ne 0 ] ; then
        echo $SUCCESS
    else
        COUNT=$(jq '.[0][0]' <<< "${OUTPUT}")
    fi
    echo ${COUNT}
    return ${SUCCESS}
}

##
# Sets up the notification function to be used based on the OS.
if [[ "${OSTYPE}" =~ darwin* ]] ; then
    NOTIFY_FUNC=notify_macos
else
    NOTIFY_FUNC=notify_linux
fi

##
#     notify ICON TITLE MESSAGE
#
# If notify-send is installed, this will pop up a desktop notification.
notify(){
    local ICON=${1}
    local TITLE=${2}
    local MESSAGE=${3}
    ${NOTIFY_FUNC} "${ICON}" "${TITLE}" "${MESSAGE}"
    local SUCCESS=$?
    echo "$TITLE"
    cat <<< "${MESSAGE}"
    return ${SUCCESS}
}

##
# Used under Linux to create a notification.
notify_linux(){
    local ICON=${1}
    local TITLE=${2}
    local MESSAGE=${3}
    notify-send -t 1000 ${ICON} "${TITLE}" "${MESSAGE}"
}

##
# Used on MacOS to create a notification.  Called by Notify if the host is any
# kind of Darwin.
notify_macos(){
    local ICON=${1}
    local TITLE=${2}
    local MESSAGE=${3}
    osascript -e "display notification \"${MESSAGE}\" with title \"${TITLE}\""
}

###
#     handle_comment AUTHOR
#
#  Reads the JSON from standard in and calls notify for a provided comment.
handle_comment(){
    local WHOM=${1}
    local HISTORY=$(cat)
    local AUTHOR=$(jq -r '.[1].author' <<< "${HISTORY}" )
    local PERMLINK=$(jq -r '.[1].permlink' <<< "${HISTORY}" )
    local PARENT_PERMLINK=$(jq -r '.[1].parent_permlink' <<< "${HISTORY}")
    local PARENT_AUTHOR=$(jq -r '.[1].parent_author' <<< "${HISTORY}")
    if [ "${AUTHOR}" != "${WHOM}" ] ; then
        local CONTENT=$(rpc_get_content "${AUTHOR}" "${PARENT_PERMLINK}")
        local TITLE=$(jq -r '.title' <<< "${CONTENT}")
        CONTENT=$(rpc_get_content "${AUTHOR}" "${PERMLINK}" | jq -r '.body')
        if [ "${PARENT_AUTHOR}" = "${WHOM}" ] ; then
            PARENT_AUTHOR="your"
        else
            PARENT_AUTHOR="${PARENT_AUTHOR}'s"
        fi
        notify "-i notification-message-im" "Comment" "${AUTHOR} just commented on ${PARENT_AUTHOR} post ${TITLE}: ${CONTENT}"
    else
        error "Skipping comment made by user"
    fi
}

##
#    handle_reward AUTHOR
#
# Reads the JSON from standard in and calls notify for a provided reward.
handle_reward(){
    local WHOM=${1}
    local HISTORY=$(cat)
    local CONTENT=$(rpc_get_content "${WHOM}" "${PARENT_PERMLINK}")
    SBD=$(jq -r '.sbd_payout' <<< "$CONTENT")
    STEEM=$(jq -r '.steem_payout' <<< "$CONTENT")
    VESTS=$(jq -r '.vesting_payout' <<< "$CONTENT")
    # maybe base icon on the size of reward?
    local ICON="-i trophy-gold"
    notify "${ICON}" "Rewards" "$(jq -r '.title' <<< "${CONTENT}"): ${SBD} ${STEEM} ${VESTS} VESTS"
}

##
#    handle_vote AUTHOR
#
# Reads the JSON from standard in and calls notify for a provided vote.
handle_vote(){
    local WHOM=${1}
    local HISTORY=$(cat)
    local VOTER=$(jq -r '.[1].voter' <<< "${HISTORY}" )
    local PERMLINK=$(jq -r '.[1].permlink' <<< "${HISTORY}")
    local AUTHOR=$(jq -r '.[1].author' <<< "${HISTORY}")
    local ICON="-i face-smile"
    if [ "${VOTER}" != "${WHOM}" ] ; then
        cat <<<${HISTORY}
        local WEIGHT=$(($(jq -r '.[1].weight' <<< "${HISTORY}")/100))
        local CONTENT=$(rpc_get_content "${AUTHOR}" "${PERMLINK}")
        if [ "${AUTHOR}" = "${WHOM}" ] ; then
            AUTHOR="your"
        else
            AUTHOR="${AUTHOR}'s"
        fi
        notify "${ICON}" "Vote!" "${VOTER} just voted ${WEIGHT}% on ${AUTHOR} post! $(jq -r '.title' <<< "${CONTENT}")"
        #FIXME: come back later and compute value of vote in SBD.
    else
        error "Skipping outgoing vote by author..."
    fi
}

##
#    handle_curation AUTHOR
#
# Reads the JSON from standard in and calls notify for a provided curation.
handle_curation(){
    local WHOM=${1}
    local HISTORY=$(cat)
    local ICON="-i trophy-silver"
    local REWARD=$(jq -r '.[1].reward' <<< "${HISTORY}")
    local PERMLINK=$(jq -r '.[1].comment_permlink' <<< "${HISTORY}" )
    local AUTHOR=$(jq -r '.[1].comment_author' <<< "${HISTORY}")
    local TITLE=$(rpc_get_content "${AUTHOR}" "${PERMLINK}" | jq -r '.title')
    if [ ! -z "${TITLE}" ] ; then
        TITLE="for ${TITLE}"
    fi
    notify "${ICON}" "Curation" "Curation reward of ${REWARD} for ${TITLE}"
}

##
#    handle_transfer AUTHOR
#
# Reads the JSON from standard in and calls notify for a provided transfer.
handle_transfer(){
    local WHOM=${1}
    local HISTORY=$(cat)
    local TO=$(jq -r '.to')
    if [ "${TO}" = "${WHOM}" ] ; then
        local ICON="-i trophy-bronze"
        local MEMO=$(jq -r '.memo' <<< "${HISTORY}")
        local AMOUNT=$(jq -r '.amount' <<< "${HISTORY}")
        local FROM=$(jq -r '.from' <<< "${HISTORY}")
        notify "${ICON}" "Transfer" "Incoming transfer from ${FROM}, ${AMOUNT} Memo: ${MEMO}"
    fi
}


##
# Global list of accounts being followed
declare -A FOLLOWING
##
# Locates followed users, checks them for updated activity, and makes notifications if any need to be made.
check_followed(){
    local WHOM=${1}
    local FOLLOW_COUNT=$(rpc_get_following_count "${WHOM}")
    local FOLLOWED=$(rpc_get_following "${WHOM}" "" ${FOLLOW_COUNT})

    for ((i=1;i<$((FOLLOW_COUNT+1));i++)) ; do
        local FOLLOWER=$(head -n $i <<< "${FOLLOWED}" | tail -n 1)
        if inlist "${FOLLOWER}" ${IGNORE[@]} ; then
            continue
        fi
        local CURRENT=$(get_event_count "${FOLLOWER}")

        if [ ! -z "${FOLLOWING[${FOLLOWER}]}" ] ; then
            if [ "${FOLLOWING[${FOLLOWER}]}" != "${CURRENT}" ] ; then
                local DIFF=$((CURRENT-${FOLLOWING[${FOLLOWER}]}))
                HISTORY=$(rpc_get_account_history "${FOLLOWER}" -1 "${DIFF}")
                for ((i=0;i<$DIFF;i++)) ; do
                    #echo $(jq -r ".[$i][0]" <<< "${HISTORY}")
                    OP=$(jq -r ".[$i][1].op[0]" <<< "${HISTORY}")
                    if [ ${#FTYPE[@]} -gt 0 ] ; then
                        if ! inlist "${OP}" "${FTYPE[@]}" ; then
                            verbose ">>>skipping follower ${OP}"
                            continue
                        fi
                    fi
                    ENTRY=$(jq -r ".[$i][1].op" <<< "${HISTORY}")
                    case "${OP}" in
                        "comment")
                            handle_comment "${WHOM}" <<< "${ENTRY}"
                            ;;
                        "vote")
                            handle_vote "${WHOM}" <<< "${ENTRY}"
                            ;;
                        "transfer")
                            handle_transfer "${WHOM}" <<< "${ENTRY}"
                            ;;
                        "author_reward")
                            handle_reward "${WHOM}" <<< "${ENTRY}"
                            ;;
                        "curation_reward")
                            handle_curation "${WHOM}" <<< "${ENTRY}"
                            ;;
                        *)
                            verbose ">>>skipping (followed) ${OP}"
                            ;;
                    esac
                done
            fi
        fi
        FOLLOWING[${FOLLOWER}]=${CURRENT}
    done
}

##
# Display help message.
usage(){
    cat << EOF
Usage:
    ${0} [-i IGNORE ...] [-t TYPE ...] -f ACCOUNT

Listen for any activity with the specified account (your account) and report on
any incoming votes, transfers, rewards, etc.

To listen for activity on any accounts you follow, provide -f and you'll also
see notifications for votes and comments on accounts you follow.

Optionally, specify names (-i INGORE) to ignore with regard to following.

Optionally, specify types (-t TYPE) of messages to watch.

Optionally, specify types (-T TYPE) of messages to watch with regard to following.

Supported TYPEs for -t and -T:

 * author_reward
 * comment
 * curation_reward
 * transfer
 * vote

EOF
}
while getopts ":fvi:t:T:" OPT ; do
    case "${OPT}" in
        f)
            FOLLOW="yes"
            ;;
        i)
            IGNORE[${#IGNORE[@]}]=${OPTARG}
            ;;
        v)
            VERBOSE="yes"
            ;;
        t)
            TYPE[${#TYPE[@]}]=${OPTARG}
            ;;
        T)
            FTYPE[${#FTYPE[@]}]=${OPTARG}
            ;;
        *)
            usage
            exit
            ;;
    esac
done
shift $((OPTIND -1))

##
#    verbose MESSAGE
# Convenience method for verbose output.
# Displays provided message if VERBOSE global is set.
verbose(){
    if [ ! -z ${VERBOSE} ] ; then
        echo $@
    fi
}

ACCOUNT=${1}
if [ -z "${ACCOUNT}" ] ;then
    error "Specify an account to watch!"
    exit 1
fi

CURRENT=$(get_event_count "${ACCOUNT}")
LAST=${CURRENT}
if [ ! -z "${FOLLOW}" ] ; then
    echo "Listening for follower activity, too."
fi
while true; do
    if [ ! -z "${FOLLOW}" ] ; then
        verbose "$(date) Checking follows..."
        check_followed "${ACCOUNT}"
        verbose "$(date) Checked follows."
    fi
    if [ "$CURRENT" -ne "$LAST" ] ; then
        COUNT=$((CURRENT-LAST))
        verbose "update needed ($COUNT)"
        HISTORY=$(rpc_get_account_history "${ACCOUNT}" -1 "${COUNT}")
        for ((i=0;i<$COUNT;i++)) ; do
            echo $(jq -r ".[$i][0]" <<< "${HISTORY}")
            OP=$(jq -r ".[$i][1].op[0]" <<< "${HISTORY}")
            ENTRY=$(jq -r ".[$i][1].op" <<< "${HISTORY}")
            if [ ${#TYPE[@]} -gt 0 ] ; then
                if ! inlist "${OP}" "${TYPE[@]}" ; then
                    verbose ">>>skipping ignored ${OP}"
                    continue
                fi
            fi
            #cat <<< "${ENTRY}"
            case "${OP}" in
                "comment")
                    handle_comment "${ACCOUNT}" <<< "${ENTRY}"
                    ;;
                "vote")
                    handle_vote "${ACCOUNT}" <<< "${ENTRY}"
                    ;;
                "author_reward")
                    handle_reward "${ACCOUNT}" <<< "${ENTRY}"
                    ;;
                "curation_reward")
                    handle_curation "${ACCOUNT}" <<< "${ENTRY}"
                    ;;
                "transfer")
                    handle_transfer "${ACCOUNT}" <<< "${ENTRY}"
                    ;;
                *)
                    verbose ">>>skipping ${OP}"
                    ;;
            esac
        done
        LAST=${CURRENT}
    fi
    sleep 0.1
    CURRENT=$(get_event_count "${ACCOUNT}")
done
