#!/bin/bash

# Scratch-build components in a side-tag

# Parameters:
# $1 - NVR
# $2 - target release, e.g.: 'f34'

# Required environment variables:
# KOJI_KEYTAB - path to the keytab that can be used to build packages in Koji
# KRB_PRINCIPAL - kerberos principal
# DIST_GIT_URL - dist-git URL
# ARCH_OVERRIDE - (optional) only build for specified architectures (example: "x86_64,i686")

if [ $# -ne 2 ]; then
    echo "Usage: $0  <nvr> <release>"
    exit 101
fi

nvr=${1}
release=${2}

build_target="${release}-build"


if [ -z "${KOJI_KEYTAB}" ]; then
    echo "Missing keytab, cannot continue..."
    exit 101
fi

if [ -z "${KRB_PRINCIPAL}" ]; then
    echo "Missing kerberos principal, cannot continue..."
    exit 101
fi

set -e
set -x

kinit -k -t ${KOJI_KEYTAB} ${KRB_PRINCIPAL}

# create a new side-tag
sidetag_name=$(fedpkg request-side-tag --base-tag ${build_target} | grep ' created.$' | awk -F\' '{ print $2 }')
date

# tag the given NVR into the side-tag
# this creates a task in koji, should be visible here:
# https://koji.fedoraproject.org/koji/tasks?method=newRepo&state=active&view=tree&order=-id
koji tag ${sidetag_name} ${nvr}
date

# wait for repo regeneration
koji wait-repo --build ${nvr} ${sidetag_name}
date

# scratch-build dependent component(s)
export LOG1=$(mktemp)
export LOG2=$(mktemp)
( koji build --scratch --wait --fail-fast ${ARCH_OVERRIDE:+--arch-override=$ARCH_OVERRIDE} ${sidetag_name} "git+${DIST_GIT_URL}/rpms/kernel#rawhide" |& tee $LOG1 ) &
( koji build --scratch --wait --fail-fast ${ARCH_OVERRIDE:+--arch-override=$ARCH_OVERRIDE} ${sidetag_name} "git+${DIST_GIT_URL}/rpms/lua#rawhide" |& tee $LOG2 ) &
wait
date

EXIT_CODE=$(awk -f parse.awk $LOG1 $LOG2)
rm $LOG1 $LOG2

exit $EXIT_CODE

