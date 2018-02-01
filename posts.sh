#!/bin/bash

##
# Display information about posts for a given user.
#
# Get and display posts for the specified user (and optionally tags.)
# Optionally exclude any articles that are tagged with EXCLUDE tag.  These can
# be displayed as handy pastable markdown links (-b) or the default of just the
# title and the permlink.  Output can be limited to a specified LIMIT and may
# even include payment information.

# Usage:
# posts.sh -b tag USER
WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

##
# On exit make the cursor visible and clean up the temporary file that was created.
cleanup(){
    if [ ! -z "${WHERE}" ] ; then
        rm "${WHERE}"
    fi
    tput cnorm
}

trap cleanup exit SIGTERM

##
# Display help message.
usage(){
    cat << EOF
Usage:
    ${0}  [-b] [-e EXCLUDE ...] [-l LIMIT] [-p] [-t TAG ...] -u <USER>

Get and display posts for the specified user (and optionally tags.) Optionally
exclude any articles that are tagged with EXCLUDE tag.  These can be displayed
as handy pastable markdown links (-b) or the default of just the title and the
permlink.  Output can be limited to a specified LIMIT and may even include
payment information.

- t TAG (filter post selection on this tag)
- b (currently the default)
- e EXCLUDE
- p show post payout information
- l LIMIT (default is 10)
- r reverse the post order
- u include user name in link
EOF
}

TIMER=0.25
LIMIT=10
ORDER=cat
while getopts ":bc:e:hl:prt:u" OPT; do
    case "${OPT}" in
        b )
            BACKLINKS=YES
        ;;
        c )
            RPC_ENDPOINT=${OPTARG}
        ;;
        e )
            EXCLUDES[${#EXCLUDES[@]}]=${OPTARG}
        ;;
        t )
            TAGS[${#TAGS[@]}]="${OPTARG}"
        ;;
        p )
            PAYOUT=YES
        ;;
        l )
            LIMIT=${OPTARG}
        ;;
        r )
            ORDER=tac
        ;;
        u )
            NAME=YES
        ;;
        *) usage
            exit
        ;;
    esac
done
shift $((OPTIND -1))

if [ -z "${1}" ] ; then
    error "No user specified!  Specify one or more users to see their post history."
    usage
else
    WHERE=$(mktemp)
    APPEND=
    for USER in $@ ; do
        if rpc_get_discussions_by_author_before_date "${USER}" '' "$(date -Iseconds)" "${LIMIT}" > "${WHERE}" ; then

            if [ ! -z "${NAME}" ] ; then
                APPEND=" by ${USER}"
            fi
            while true ; do
                read -r PERMLINK
                if [ -z "${PERMLINK}" ] ; then
                    break;
                fi
                read -r URL
                read -r ROOT_TITLE
                read -r CATEGORY
                read -r PENDING_PAYOUT_VALUE
                read -r TOTAL_PAYOUT_VALUE
                read -r CURATOR_PAYOUT_VALUE
                read -r JSON_METADATA
                TAGGED=( $(jq -r ".tags []" <<< "${JSON_METADATA}" ) )
                TAGGED[${#TAGGED[@]}]=${CATEGORY}

                PASS=yes
                if [ ! -z "${TAGS[@]}" ] ; then
                    #make sure the post has the specified tags
                    PASS=
                    if listinlist "${TAGS[*]}" "${TAGGED[*]}" ; then
                        PASS=yes
                    fi
                fi
                if [ -z "${PASS}" ] ; then
                    continue
                fi
                if [ ! -z "${EXCLUDES}"  ]  ; then
                    if listinlist "${EXCLUDES[*]}" "${TAGGED[*]}"; then
                        continue
                    fi
                fi
                if [ ! -z "${BACKLINKS}" ]  ; then
                    LINE="[${ROOT_TITLE}${APPEND}](${URL})"
                else
                    LINE="${ROOT_TITLE}${APPEND} (${PERMLINK})"
                fi
                if [ ! -z "${PAYOUT}" ] ; then
                    LINE="${LINE} - pending payout: ${PENDING_PAYOUT_VALUE} total: ${TOTAL_PAYOUT_VALUE} curator: ${CURATOR_PAYOUT_VALUE}"
                fi

                echo "${LINE}"

            done < <(jq -r ".[]  | .permlink, .url, .root_title, .category, .pending_payout_value, .total_payout_value, .curator_payout_value, .json_metadata" < "${WHERE}") | "${ORDER}"
        fi
    done
fi
