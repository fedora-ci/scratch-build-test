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
dnf --quiet -y install mass-prebuild copr-cli expect
copr-cli whoami
unbuffer mpb |& tee ~/_mpb.log
test -e ~/.mpb/mpb.log && cat ~/.mpb/mpb.log
bi=\$(cat ~/_mpb.log | tr '"' ' ' | awk '/mpb --buildid/ {print \$3; exit}')
rm -fv _test_protocol.log
mpb-report --buildid \$bi --verbose --output _test_protocol.log
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

# Testing is complete now. Let's show whole the test protocol:
cat _test_protocol.log

# Now we need to determine the final testcase status. The agreed criterion is
# to look for packages that failed to build. So far we can't use the mpb-report
# exitcode to indicate the testcase result. So we resort to grepping through
# the textual output of mpb-report. First we separate out the list of failed
# packages into _failed.log:
cat _test_protocol.log |\
  sed -n -e '/^## List of failed packages/,/^## List of packages with unknown status/p' |\
  grep -v '^$' |\
  tee _failed.log

# Now the expected content of _failed.log in case testing was successful is:
## List of failed packages
## List of packages with unknown status
# That's two lines of acceptable text.  If there is no more text in the _failed.log
# then the test as a whole PASSED.  Otherwise the test FAILED.
cnt=$(cat _failed.log | wc -l)
ecode=0
test $cnt -ne 2 && ecode=1

exit $ecode
