#!/bin/bash
# Build with the Sailfish SDK (sfdk) and install on a phone reachable over SSH
# (developer mode). Adjust PHONE / PORT / KEY for your setup.
set -e
PHONE=${PHONE:-defaultuser@127.0.0.1}
PORT=${PORT:-2233}
KEY=${KEY:-$HOME/.ssh/id_rsa}
D=$(cd $(dirname $0); pwd); cd $D/..
~/SailfishOS/bin/sfdk -c target=SailfishOS-5.1.0.11-aarch64 build 2>&1 | grep -v D-Bus | grep -E "error|Error|Wrote:|Fatal|required" | head -30
RPM=$(ls -t RPMS/*.rpm | head -1)
scp -q -i "$KEY" -o IdentitiesOnly=yes -P $PORT $RPM $PHONE:/tmp/
ssh -i "$KEY" -o IdentitiesOnly=yes -p $PORT $PHONE "devel-su rpm -U --force /tmp/$(basename $RPM); rpm -q harbour-todotxt"
