#!/bin/sh

set -e
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH
umask 077

cd /
renice 0 -p "$$" >/dev/null 2>&1 || true
env -i -- setsid /usr/local/wireguard/on-boot.sh </dev/null >>/tmp/kobo-wireguard-boot.log 2>&1 &
