#!/bin/bash

set -xe

true ==========================================================================

env | sort

true ==========================================================================

cat /etc/os-release

true ==========================================================================

# cat > /etc/yum.repos.d/mass-prebuild.repo <<EOF1
# [copr:copr.fedorainfracloud.org:fberat:mass-prebuild]
# name=Copr repo for mass-prebuild owned by fberat
# baseurl=https://download.copr.fedorainfracloud.org/results/fberat/mass-prebuild/epel-8-\$basearch/
# type=rpm-md
# skip_if_unavailable=True
# gpgcheck=1
# gpgkey=https://download.copr.fedorainfracloud.org/results/fberat/mass-prebuild/pubkey.gpg
# repo_gpgcheck=0
# enabled=1
# enabled_metadata=1
# EOF1
# 
# 
# yum -y --enablerepo=epel install /usr/bin/mpb ||:
# 
# c='/etc/ssh/sshd_config'
# sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/' $c;
# systemctl restart sshd.service
# echo -e "redhat\nredhat\n" | passwd root
# ip a | fgrep glo
# set +x
# while true; do
#     sleep 1
#     test -f /goon && break
# done

cp dejagnu-1.6.3-6.fc38.src.rpm /tmp/
cp -r .mpb ~/
mpb ||:
cat /root/.mpb/mpb.log


exit 0
