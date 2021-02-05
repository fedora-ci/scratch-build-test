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

# tag the given NVR into the side-tag
koji tag ${sidetag_name} ${nvr}

function wait_and_get_exit_codes() {
    children=("$@")
    EXIT_CODE=0
    for job in "${children[@]}"; do
       CODE=0;
       wait ${job} || CODE=$?
       if [[ "${CODE}" != "0" ]]; then
           EXIT_CODE=1;
       fi
   done
}

set +e

# scratch-build dependent component(s)
# kernel:

commands=(
    "koji build --scratch --wait --fail-fast ${ARCH_OVERRIDE:+--arch-override=$ARCH_OVERRIDE} ${sidetag_name} \"git+${DIST_GIT_URL}/rpms/sshpass#rawhide\""
    "koji build --scratch --wait --fail-fast ${ARCH_OVERRIDE:+--arch-override=$ARCH_OVERRIDE} ${sidetag_name} \"git+${DIST_GIT_URL}/rpms/spindown#rawhide\""
)

clen=`expr "${#commands[@]}" - 1`

children_pids=()
for i in `seq 0 $clen`; do
    (echo "${commands[$i]}" | bash) &
    children_pids+=("$!")
done

EXIT_CODE=0
wait_and_get_exit_codes "${children_pids[@]}"
exit $EXIT_CODE

