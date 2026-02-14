#!/bin/sh

set -e
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH

if [ ! -d /dev/pts ]; then
  mkdir -p /dev/pts
fi
if ! grep -q ' /dev/pts ' /proc/mounts; then
  mount -t devpts devpts /dev/pts || true
fi

if [ ! -c /dev/net/tun ]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
fi

if timeout 5 sh -c "while ! grep -q ' /mnt/onboard ' /proc/mounts; do sleep 0.1; done"; then
  /usr/local/wireguard/start.sh
fi

exit 0
