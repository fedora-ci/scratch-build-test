#!/bin/bash

set -xe

_name=$1
_branch=$2
_sidetag=$3

_tmpd=$(mktemp -d)
pushd $_tmpd
counter=0
until fedpkg clone --anonymous $_name; do
    test $counter -gt 3 && break
    counter=$((counter + 1))
    sleep 120
done
cd $_name

# For rawhide, we use "latest released" branch
# because rawhide isn't always safely rebuildable
# and that was causing false positives of this test
fedpkg switch-branch | fgrep $_branch ||
    _branch=$(fedpkg switch-branch |\
              grep -P '^\ +origin/f\d\d$' |\
              grep -Po 'f\d\d' |\
              sort |\
              tail -1)

fedpkg switch-branch $_branch
# the glibc spec contains comments that CentOS 8 fails to parse
sed -i '/^%dnl /'d glibc.spec ||:
fedpkg build --scratch --fail-fast --target=$_sidetag
popd
rm -rf $_tmpd

set +xe

