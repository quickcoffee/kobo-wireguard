#!/bin/sh

set -e
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

mkdir -p /dev/pts
if ! grep -q ' /dev/pts ' /proc/mounts; then
  mount -t devpts devpts /dev/pts || true
fi

exec /usr/local/wireguard/service.sh watch
