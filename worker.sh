#!/bin/bash

set -xe

_name=$1
_branch=$2
_sidetag=$3
_arches=$4

_tmpd=$(mktemp -d)
pushd $_tmpd
counter=0
until fedpkg clone --anonymous --depth=1  $_name; do
    test $counter -gt 3 && break
    counter=$((counter + 1))
    sleep 120
done
cd $_name

# # For rawhide, we use "latest released" branch
# # because rawhide isn't always safely rebuildable
# # and that was causing false positives of this test
# fedpkg switch-branch | fgrep $_branch ||
#     _branch=$(fedpkg switch-branch |\
#               grep -P '^\ +origin/f\d\d$' |\
#               grep -Po 'f\d\d' |\
#               sort |\
#               tail -1)

fedpkg switch-branch $_branch || fedpkg switch-branch main

# Building specfile with uncommitted changes is possible with --srpm
CMDLINE_SRPM=""

# The strace testsuite is known for its flakiness. Disable it.
if test "$_name" == "strace"; then
    sed -i '/^%check/a exit 0' strace.spec
    CMDLINE_SRPM="--srpm"
fi

# The glibc specfile contains %dnl macros, CentOS 8 fedpkg can't parse it.
if test "$_name" == "glibc" -o "$_name" == "qemu" && grep '^%dnl ' $_name.spec; then
    sed -i '/^%dnl /'d $_name.spec
    CMDLINE_SRPM="--srpm"
fi

fedpkg build --scratch --fail-fast $CMDLINE_SRPM --target=$_sidetag --arches=$_arches

popd
rm -rf $_tmpd

set +xe

