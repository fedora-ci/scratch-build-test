#!/bin/bash

# Scratch-build components in a side-tag

# List the components to rebuild
COMPONENT_LIST="kernel lua opencryptoki"

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

# Run the scratchbuilds in parallel
TMPFILES=""
for comp in ${COMPONENT_LIST}; do
    export t=$(mktemp /tmp/tmp-${comp}-XXXXXXXX)
    TMPFILES="${TMPFILES} ${t}"
    ( ./worker.sh ${comp} ${release} ${sidetag_name} |& tee ${t} ) &
    unset t
done
wait
date

# Check for build errors
EXIT_CODE=0
for t in ${TMPFILES}; do
    e=$(awk -f parse.awk ${t})
    EXIT_CODE=$((EXIT_CODE + e))
    rm ${t}
done

# remove the side-tag as it is no longer needed
fedpkg remove-side-tag ${sidetag_name}

exit ${EXIT_CODE}
