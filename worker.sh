#!/bin/bash

set -xe

_name=$1
_branch=$2
_sidetag=$3

true v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v
env | sort
true ^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^

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
fedpkg switch-branch | fgrep $_branch ||
    _branch=$(fedpkg switch-branch | grep -Po 'f\d\d' | tail -1)

fedpkg switch-branch $_branch
fedpkg build --scratch --fail-fast --target=$_sidetag
popd
rm -rf $_tmpd

set +xe

