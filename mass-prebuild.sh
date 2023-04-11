#!/bin/bash

set -x

FEDRELEASE=38
TESTBUILD=${1}

export HOME=${HOME:-/root}
export SHELL=${SHELL:-/bin/bash}


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

PKGLIST=''
for i in toolbox yamllint; do
    rpm -q $i || PKGLIST="$PKGLIST $i"
done
if [ "x$PKGLIST" != "x" ]; then
    dnf -y install --enablerepo=epel $PKGLIST
fi

rm -rvf ~/.{cache,mpb,config}

# Set up copr config, namely user id hash
mkdir -p ~/.config
cat $COPR_CONFIG > ~/.config/copr

# Set up the c8s worker
cat > work.sh <<EOFA
#!/bin/bash
set -x
cat /etc/redhat-release
dnf -y copr enable fberat/mass-prebuild
dnf -y install mass-prebuild copr-cli expect
copr-cli whoami
unbuffer mpb |& tee ~/output.log
test -e ~/.mpb/mpb.log && cat ~/.mpb/mpb.log
true "v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v_v"
bi=\$(cat ~/output.log | tr '"' ' ' | awk '/mpb --buildid/ {print \$3; exit}')
rm -fv mpb*report.md
mpb-report --buildid \$bi --verbose
cat mpb*report.md
true "^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^"
EOFA

# koji download-build $TESTBUILD --arch=src
# SRPM=$(readlink -f *.src.rpm)

# Set up mass-prebuild tool
mkdir ~/.mpb
cat > ~/.mpb/config <<EOFB
packages:
  glibc:
    deps_only: true
build_id: 0
verbose: 5
revdeps:
  list:
    kernel:
      committish: '@last_build'
    lua:
      committish: '@last_build'
    opencryptoki:
      committish: '@last_build'
    strace:
      committish: '@last_build'
    '@critical-path-base':
      committish: '@last_build'
copr:
  additional_repos:
    - ${BUILD_URL}artifact/REPO/
EOFB
cat ~/.mpb/config
yamllint ~/.mpb/config

# toolbox list -vvvv 
toolbox list | fgrep fedora-toolbox-${FEDRELEASE} || \
	toolbox -y create --distro fedora --release ${FEDRELEASE}
toolbox run --container fedora-toolbox-${FEDRELEASE} bash work.sh




exit 0
