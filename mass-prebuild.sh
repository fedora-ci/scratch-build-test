#!/bin/bash

set -x

mkdir -p ~/.config
cat $COPR_CONFIG > ~/.config/copr

cp -r .mpb ~/
copr-cli whoami
mpb 

exit 0
