#!/bin/sh

echo "This repository now uninstalls WireGuard, not Tailscale."
exec ./uninstall-wireguard.sh "$@"
