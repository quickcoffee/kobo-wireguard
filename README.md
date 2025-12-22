# kobo-wireguard
Install scripts for getting [WireGuard](https://www.wireguard.com) VPN running on Kobo e-readers and persisting through reboots.

## Supported devices
- *Kobo Libra 2*
- *Kobo Libra Colour*/*Kobo Libra Color*
- *Kobo Clara BW*

If you have another device and would like to contribute, please open a PR!

## Prerequisites
Before installation, you need to:
1. Build WireGuard tools (`wg` and `wg-quick`) for ARM architecture
2. Place the compiled binaries in the `binaries/wireguard/` directory of your device folder
3. Create a WireGuard configuration file (see Configuration section below)

## Installation
1. Download this repo onto your Kobo e-reader's onboard storage and find your device directory.
2. Ensure WireGuard binaries are present in the device's `binaries/wireguard/` directory.
3. Run `install-wireguard.sh` from the chosen device's directory.
4. Create your WireGuard configuration file at `/mnt/onboard/wireguard/config/wg0.conf` (see Configuration section).
5. Reboot your Kobo, and WireGuard will automatically start!

## Configuration
Create a WireGuard configuration file at `/mnt/onboard/wireguard/config/wg0.conf` with your VPN settings.

Example configuration:
```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = your.server.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

You can generate keys using:
```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

## Manual Control
- Bring up the VPN: `wg-quick up wg0`
- Bring down the VPN: `wg-quick down wg0`
- Check status: `wg show`

## Uninstallation
Simply run `uninstall-wireguard.sh` from the chosen device's directory in the repo.

## Building WireGuard Binaries
To build WireGuard tools for ARM:
```bash
wget https://git.zx2c4.com/wireguard-tools/snapshot/wireguard-tools-1.0.20210914.tar.xz
tar -xvf wireguard-tools-1.0.20210914.tar.xz
cd wireguard-tools-1.0.20210914/src
make CC=arm-linux-gnueabi-gcc WITH_BASHCOMPLETION=no WITH_SYSTEMDUNITS=no WITH_WGQUICK=yes
```

Copy the resulting `wg` binary and `wg-quick/linux.bash` (rename to `wg-quick`) to your device's `binaries/wireguard/` directory.

## Acknowledgements
[Dylan Staley for initial work and scripts on the Kobo Sage](https://dstaley.com/posts/tailscale-on-kobo-sage)

[jmacindoe for documenting kernel module compilation on Kobo readers](https://github.com/jmacindoe/kobo-kernel-modules)

Original Tailscale implementation that this was adapted from: [kobo-tailscale](https://github.com/sublimino/kobo-tailscale)
