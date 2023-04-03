#!/bin/bash

set -x

rm -rf ~/.cache/copr/*

mkdir -p ~/.config
cat $COPR_CONFIG > ~/.config/copr

cp -r .mpb ~/
copr-cli whoami
yum -y install strace
strace -f mpb

exit 0
