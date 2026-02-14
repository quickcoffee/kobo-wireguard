# Kobo Clara BW

## Modules
WireGuard requires the TUN/TAP device driver. This device family already exposes TUN, so no extra kernel module is installed.

## WireGuard binaries
Before running `install-wireguard.sh`, place ARMv7 binaries in `binaries/wireguard/`:

- `wireguard-go`
- `wg`

## Runtime files
Create these files on device storage:

- `/mnt/onboard/wireguard/wg0.conf` (required)
- `/mnt/onboard/wireguard/wg0.addresses` (optional)
- `/mnt/onboard/wireguard/wg0.routes` (optional)
- `/mnt/onboard/wireguard/wg0.dns` (optional, one DNS server IP per line)
