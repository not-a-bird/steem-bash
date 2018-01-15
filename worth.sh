#!/bin/bash

##
# This script fetches the total worth of the specified user, provide a user
# name as an argument.

WHEREAMI=$(dirname ${BASH_SOURCE[0]})
if [ ${WHEREAMI} != '.' ] ; then
    WHEREAMI=$(readlink ${WHEREAMI})
fi

. "${WHEREAMI}"/functions.sh

if [ -z "${1}" ] ; then
    error "No user specified!  Specify a user (without the @) to see the total worth of their account!"
else
    get_bank "${1}"
fi
