#!/bin/sh

echo "This repository now installs WireGuard, not Tailscale."
exec ./install-wireguard.sh "$@"
