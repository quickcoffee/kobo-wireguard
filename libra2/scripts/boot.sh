#!/bin/sh

renice 0 -p $$
env -i -- setsid /usr/local/wireguard/on-boot.sh &
exit 0
