#!/bin/bash

set -x

rm -rf ~/.cache/copr/*

mkdir -p ~/.config
cat $COPR_CONFIG > ~/.config/copr

cp -r .mpb ~/
copr-cli whoami
yum install -y expect
hostname
ip a 
unbuffer mpb



exit 0
