#!/bin/bash

set -x

mkdir -p ~/.config
cat $COPR_CONFIG > ~/.config/copr

cp -r .mpb ~/
mpb >& output.log
tail -1000 output.log
cat /root/.mpb/mpb.log

exit 0
