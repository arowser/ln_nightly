#!/bin/bash -x
set -e

CWD=$(pwd)
export SLOW_MACHINE=1
export CC=${COMPILER:-gcc}
export DEVELOPER=${DEVELOPER:-1}
export EXPERIMENTAL_FEATURES=${EXPERIMENTAL_FEATURES:-0}
export SOURCE_CHECK_ONLY=${SOURCE_CHECK_ONLY:-"false"}
export COMPAT=${COMPAT:-1}
export PATH=$CWD/dependencies/bin:"$HOME"/.local/bin:"$PATH"
export PYTEST_PAR=2
export PYTHONPATH=$PWD/contrib/pylightning:$PYTHONPATH
# If we're not in developer mode, tests spend a lot of time waiting for gossip!
# But if we're under valgrind, we can run out of memory!
if [ "$DEVELOPER" = 0 ] && [ "$VALGRIND" = 0 ]; then
    PYTEST_PAR=4
fi

mkdir -p dependencies/bin || true

# Download bitcoind and bitcoin-cli 
if [ ! -f dependencies/bin/bitcoind ]; then
    wget https://bitcoincore.org/bin/bitcoin-core-0.18.1/bitcoin-0.18.1-aarch64-linux-gnu.tar.gz
    tar -xzf bitcoin-0.18.1-aarch64-linux-gnu.tar.gz
    mv bitcoin-0.18.1/bin/* dependencies/bin
    rm -rf bitcoin-0.18.1-aarch64-linux-gnu.tar.gz
fi

cd lightning
pip3 install --upgrade setuptools
pip3 install --user -r requirements.txt -r tests/requirements.txt -r doc/requirements.txt
pip3 install --quiet \
     pytest-test-groups==1.0.3

echo "Configuration which is going to be built:"
echo -en 'travis_fold:start:script.1\\r'
./configure CC="$CC"
cat config.vars
echo -en 'travis_fold:end:script.1\\r'

cat > pytest.ini << EOF
[pytest]
addopts=-p no:logging --color=no --force-flaky
EOF


if [ "$SOURCE_CHECK_ONLY" == "false" ]; then
    echo -en 'travis_fold:start:script.2\\r'
    make -j3 > /dev/null
    echo -en 'travis_fold:end:script.2\\r'

    echo -en 'travis_fold:start:script.3\\r'
    make -j$PYTEST_PAR check
    echo -en 'travis_fold:end:script.3\\r'
else
    git clone https://github.com/lightningnetwork/lightning-rfc.git
    echo -en 'travis_fold:start:script.2\\r'
    make -j3 > /dev/null
    echo -en 'travis_fold:end:script.2\\r'
    make check-source BOLTDIR=lightning-rfc
fi
