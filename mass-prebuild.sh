#!/bin/bash

set -x

FEDRELEASE=38

TESTBUILD=$1

if [ -z "${TESTBUILD}" ]; then
    echo "Missing build to test, cannot continue..."
    exit 101
fi

if [ -z "${KOJI_KEYTAB}" ]; then
    echo "Missing keytab, cannot continue..."
    exit 101
fi

if [ -z "${KRB_PRINCIPAL}" ]; then
    echo "Missing kerberos principal, cannot continue..."
    exit 101
fi

if [ -z "${COPR_CONFIG}" ]; then
    echo "Missing COPR configuration, cannot continue..."
    exit 101
fi


rm -rf ~/.cache/copr/*
mkdir -p ~/.config
cat $COPR_CONFIG > ~/.config/copr

cat > work.sh <<EOFA
#!/bin/bash
cat /etc/redhat-release
dnf -y copr enable fberat/mass-prebuild
dnf -y install mass-prebuild copr-cli expect
copr-cli whoami
unbuffer mpb
EOFA

koji download-build $TESTBUILD --arch=src
SRPM=$(readlink -f *.src.rpm)

mkdir .mpb
cat > .mpb/config <<EOFB
packages:
  colorgcc:
    src_type: file
    src: $SRPM
build_id: 0
verbose: 5
revdeps:
  list:
    - colorgcc
EOFB

cat .mpb/config

export HOME=${HOME:-/root}
export SHELL=${SHELL:-/bin/bash}

rpm -q toolbox || \
	dnf -y install --enablerepo=epel toolbox
# toolbox list -vvvv 
toolbox list | fgrep fedora-toolbox-${FEDRELEASE} || \
	toolbox -y create --distro fedora --release ${FEDRELEASE}
toolbox run --container fedora-toolbox-${FEDRELEASE} bash work.sh

exit 0
