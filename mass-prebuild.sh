#!/bin/bash

set -x

mkdir -p ~/.config
cat $COPR_CONFIG > ~/.config/copr

cp -r .mpb ~/
mpb 
cat /root/.mpb/mpb.log

exit 0
