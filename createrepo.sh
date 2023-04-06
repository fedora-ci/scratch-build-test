#!/bin/bash

set -x

yum -y install createrepo

TESTBUILD=$1

rm -rf REPO
mkdir REPO
pushd REPO
true ===========================================================
koji download-build $TESTBUILD --arch=x86_64 --arch=noarch
createrepo .
env | sort
pwd
true ===========================================================
popd
