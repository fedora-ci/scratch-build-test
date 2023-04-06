#!/bin/bash

set -x

yum -y install createrepo

TESTBUILD=$1

mkdir artifacts
pushd artifacts
true ===========================================================
koji download-build $TESTBUILD --arch=x86_64 --arch=noarch
createrepo .
env | sort
pwd
true ===========================================================
popd
sleep 10m
