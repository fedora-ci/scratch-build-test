#!/bin/bash

set -x

TESTBUILD=$1

yum -y install createrepo

rm -rf REPO
mkdir REPO
pushd REPO
koji download-build $TESTBUILD --arch=x86_64 --arch=noarch --quiet
createrepo .
popd
du -sh REPO
