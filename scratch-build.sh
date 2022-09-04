#!/bin/bash

trap "exit 1" TERM
export TOP_PID=$$

# Scratch-build components in a side-tag
set -e

# tools
rhpkg=fedpkg
brew=koji

if [ $# -ne 2 ]; then
    echo "Manually running scratch-build test..."
    echo "----------------------------------------------------------------"
    read -p "Comma separated NVRs (e.g. gcc-11.2.1-6.1.el9) : " nvrs
    read -p "target release (e.g. rhel-9.0.0) : " release
else
    set -x

    # Parameters:
    # $1 - NVR
    # $2 - target release, e.g.: 'f34'
    nvrs=${1}
    release=${2}

    # Required environment variables:
    # KOJI_KEYTAB - path to the keytab that can be used to build packages in Koji
    # KRB_PRINCIPAL - kerberos principal
    # DIST_GIT_URL - dist-git URL
    # ARCH_OVERRIDE - (optional) only build for specified architectures (example: "x86_64,i686")
    # env | sort

    if [ -z "${KOJI_KEYTAB}" ]; then
        echo "Missing keytab, cannot continue..."
        exit 101
    fi

    if [ -z "${KRB_PRINCIPAL}" ]; then
        echo "Missing kerberos principal, cannot continue..."
        exit 101
    fi

    kinit -k -t ${KOJI_KEYTAB} ${KRB_PRINCIPAL}
fi

# identify the worker
# echo "----------------------------------------------------------------"
# cat /etc/*-release
# rpm -qf `which ${rhpkg}`
# echo "----------------------------------------------------------------"

set -x

# components under rebuild test
if [[ ${nvrs} == *systemtap* ]]; then
    # Skip building qemu, since it builds too long for a gating test
    components="glibc"
elif [[ ${nvrs} == *redhat-rpm-config* ]]; then
    components="zlib"
elif [ ${nvrs} == llvm -o ${nvrs} == clang ]; then
    components="clang llvm kernel"
else
    # Skip building strace temporarily because of
    # https://bugzilla.redhat.com/show_bug.cgi?id=1929836
    components="kernel lua opencryptoki"
fi

# supported architectures
testarches="aarch64 i686 ppc64le s390x x86_64"

# place to store the buildsystem test logs
testlogdir=`mktemp -d`

do_rebuilds()
{
    _stage=$1
    for testarch in ${testarches}; do
        for component in ${components}; do
            export buildlog="${testlogdir}/${component}.${testarch}.${_stage}"
            ( ./worker.sh ${component} ${release} ${sidetag_name} ${testarch} |& tee ${buildlog} ) &
        done
    done
    wait
}

# create a new side-tag
build_target="${release}-build"
sidetag_name=$(${rhpkg} request-side-tag --base-tag ${build_target} | grep ' created.$' | awk -F\' '{ print $2 }')
date

# Set up a baseline by rebuilding in a side tag not having component under test
do_rebuilds 'baseline'
date

# tag the given NVR into the side-tag
for nvr in ${nvrs//,/\ }; do
    ${brew} tag ${sidetag_name} ${nvr}
done
date

# wait for repo regeneration
for nvr in ${nvrs//,/\ }; do
    ${brew} wait-repo --build ${nvr} ${sidetag_name} || \
    ${brew} wait-repo --build ${nvr} ${sidetag_name}
done
date

# Run the actual rebuild tests within a buildroot having the component under test
do_rebuilds 'test'
date


## Evaluate test results

set +x

testresult()
{
    _log=$1
    if ! test -f ${_log}; then
        echo "ERROR: Test log doesn't exist" 1>&2
        kill -s TERM $TOP_PID
    fi
    if grep -qE '^[0-9]+\ build.*completed\ successfully$' ${_log}; then
        echo "PASS"
    elif grep -qE '^[0-9]+\ build.*failed$' ${_log}; then
        echo "FAIL"
    else
        echo "ERROR: Missing expected pattern in ${_log}" 1>&2
        kill -s TERM $TOP_PID
    fi
}

buildurl()
{
    _log=$1
    echo -n "  $(basename $_log) "
    fgrep 'https://koji.fedoraproject.org/koji/taskinfo' $_log
}

exit_code=0
test_cnt=0
fail_cnt=0
for component in ${components}; do
    for testarch in ${testarches}; do
        test_cnt=$((test_cnt + 1))
        _baselog="$testlogdir/${component}.${testarch}.baseline"
        _testlog="$testlogdir/${component}.${testarch}.test"
        r1=$(testresult $_baselog)
        r2=$(testresult $_testlog)
        if [[ "$r1" == "FAIL" ]] && [[ "$r2" == "FAIL" ]]; then
            echo "WARNING: ${component}.${testarch} failed rebuilds"
            buildurl $_baselog
            buildurl $_testlog
            fail_cnt=$((fail_cnt + 1))
        elif [[ "$r1" == "FAIL" ]] && [[ "$r2" == "PASS" ]]; then
            echo "WARNING: ${component}.${testarch} improvement"
            buildurl $_baselog
            buildurl $_testlog
        elif [[ "$r1" == "PASS" ]] && [[ "$r2" == "PASS" ]]; then
            echo "INFO: ${component}.${testarch} passed rebuilds"
            buildurl $_baselog
            buildurl $_testlog
        elif [[ "$r1" == "PASS" ]] && [[ "$r2" == "FAIL" ]]; then
            echo "ERROR: ${component}.${testarch} regression"
            echo "vvvvvvvvvvvv  BASELINE  vvvvvvvvvvvv"
            cat $_baselog
            echo "^^^^^^^^^^^^  BASELINE  ^^^^^^^^^^^^"
            echo "vvvvvvvvvvvv  TEST  vvvvvvvvvvvv"
            cat $_testlog
            echo "^^^^^^^^^^^^  TEST  ^^^^^^^^^^^^"
            exit_code=1
            fail_cnt=$((fail_cnt + 1))
        else
            echo "ERROR: We should never get here" 1>&2
            kill -s TERM $TOP_PID
        fi
    done
done
wait
date


if test $fail_cnt -ge $((test_cnt / 2)); then
    echo "ERROR: Failure rate too high"
    echo "$fail_cnt tests out of $test_cnt failed"
    exit_code=1
fi

# try to remove the side-tag as it is no longer needed
${rhpkg} remove-side-tag ${sidetag_name} ||:

set +x

if test $exit_code -eq 0; then
    echo "TESTING PASSED"
else
    echo "TESTING FAILED"
fi

exit ${exit_code}

