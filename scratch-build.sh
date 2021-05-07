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

true v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v
env | sort
true ^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^

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
# koji wait-repo --build ${nvr} ${sidetag_name}
# date

# scratch-build dependent component(s)
export LOG1=$(mktemp)
export LOG2=$(mktemp)
export LOG3=$(mktemp)
#( ./worker.sh kernel ${release} ${sidetag_name} |& tee ${LOG1} ) &
#( ./worker.sh lua ${release} ${sidetag_name} |& tee ${LOG2} ) &
#( ./worker.sh opencryptoki ${release} ${sidetag_name} |& tee ${LOG3} ) &
( ./worker.sh elfutils ${release} ${sidetag_name} |& tee ${LOG3} ) &
wait
date

EXIT_CODE=$(awk -f parse.awk ${LOG1} ${LOG2} ${LOG3})
rm ${LOG1} ${LOG2} ${LOG3}

exit ${EXIT_CODE}

