# kobo-wireguard
Install scripts for getting WireGuard running on Kobo e-readers and persisting through reboots.

## Supported devices
- Kobo Libra 2
- Kobo Libra Colour (Color)
- Kobo Clara BW

If you have another device and would like to contribute, please open a PR.

## Important requirements
The mod uses the userspace stack (`wireguard-go` and `wg`). Each device folder includes both ARMv7 binaries.

The device must provide a working TUN driver, the `ip` and `timeout` commands, and `flock` (a standalone command or a BusyBox applet). The Libra 2 installer includes a TUN module that must match its running kernel.

## Installation
1. Copy your device directory to the Kobo's onboard storage.
2. Open that directory in a root shell and run `sh install-wireguard.sh`. If upgrading from the earlier scripts, first stop an active tunnel with the installed `/usr/local/wireguard/stop.sh`.
3. Create `/mnt/onboard/wireguard/wg0.conf` with the client key and peer settings.
4. Add `/mnt/onboard/wireguard/wg0.addresses` with the assigned tunnel address in CIDR notation, such as `10.8.0.2/32`.
5. Add `/mnt/onboard/wireguard/wg0.routes` with the remote subnets to reach over the tunnel, such as `10.20.0.0/24`. A subnet already covered by the tunnel address does not require a separate route.
6. Optionally create `/mnt/onboard/wireguard/wg0.dns` with one DNS server IP per line.

## Config notes
`wg0.conf` is passed directly to `wg setconf`. Move `Address=` and `DNS=` values from a wg-quick profile into the corresponding sidecar files and remove any other wg-quick-only directives. Put one value per line in each sidecar. Blank lines and `#` comments are accepted.

The mod sets up split-tunnel routing. Make sure each remote subnet is covered by the relevant peer's `AllowedIPs` and routed through `wg0.routes` or a connected tunnel subnet. Default routes such as `0.0.0.0/0` and `::/0` in `wg0.routes` are rejected to preserve the peer endpoint's network path.

The DNS override is applied after address and route setup succeeds. On stop, the previous resolver settings are restored if the current settings still match the override.

## Starting and stopping

The monitor starts on installation and boot. It waits for an addressed uplink with a default route, retries failed starts, and reconfigures the tunnel when it detects a connection change. To attempt setup immediately, run `/usr/local/wireguard/start.sh`. Run `/usr/local/wireguard/stop.sh` to stop the tunnel until a detected reconnect, an explicit start, or a reboot.

Automatic setup logs to `/tmp/kobo-wireguard/wg0.setup.log`. The daemon logs to `/wg0-wireguard-go.log`. After generating traffic to a remote IP, use `wg show wg0` to check for a handshake and `ip route get <remote-IP>` to check the selected route.

### NickelMenu

If NickelMenu is installed, add these lines to a file in `/mnt/onboard/.adds/nm/` to show tunnel status and toggle it from the main menu.

```text
menu_item :main :WireGuard Status :cmd_output :6000:/usr/local/wireguard/service.sh status
menu_item :main :Toggle WireGuard :cmd_output :6000:/usr/local/wireguard/service.sh toggle
```

Turning WireGuard off from the menu persists across Wi-Fi reconnects and reboots. Use the toggle or `start.sh` to enable it again.

## Building ARMv7 binaries
`tools/build-armv7.sh` uses Docker to cross-compile:
- `wireguard-go` from `https://github.com/WireGuard/wireguard-go`
- `wg` from `https://git.zx2c4.com/wireguard-tools`

The script writes outputs to `dist/armv7/` and stages them into:
- `libra2/binaries/wireguard/`
- `libra-color/binaries/wireguard/`
- `clara-bw/binaries/wireguard/`

Useful overrides:
- `WIREGUARD_GO_REF=<tag-or-branch>`
- `WIREGUARD_TOOLS_REF=<tag-or-branch>`
- `WG_LDFLAGS=''` (if static linking fails)
- `TARGET_DEVICES='libra2'` (build/stage only one device)

Default tool refs:
- `WIREGUARD_GO_REF=master`
- `WIREGUARD_TOOLS_REF=v1.0.20250521`

## Uninstallation
Run `uninstall-wireguard.sh` from your device directory.
Remove the WireGuard NickelMenu entries if you added them.

## Acknowledgements
- Based on [videah/kobo-tailscale](https://github.com/videah/kobo-tailscale).
- [Dylan Staley for early Kobo networking scripts](https://dstaley.com/posts/tailscale-on-kobo-sage)
- [jmacindoe for Kobo kernel module documentation](https://github.com/jmacindoe/kobo-kernel-modules)
