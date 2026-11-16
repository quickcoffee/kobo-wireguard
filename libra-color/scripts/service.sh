#!/bin/sh

export PATH=/usr/sbin:/usr/bin:/sbin:/bin:$PATH
umask 077

WG_IFACE="${WG_IFACE:-wg0}"
WG_DIR=/mnt/onboard/wireguard
RUN_DIR=/tmp/kobo-wireguard
RESOLV_CONF=/etc/resolv.conf
TUN_MODULE=/lib/modules/wireguard/kernel/drivers/net/tun.ko

error() {
  printf 'WireGuard (%s): %s\n' "$WG_IFACE" "$*" >&2
  return 1
}

case "$WG_IFACE" in
  -*|*[!a-zA-Z0-9_=+.-]*|.|..) error "Invalid interface name"; exit 1 ;;
esac
if [ "${#WG_IFACE}" -gt 15 ]; then
  error "Interface name exceeds 15 characters"
  exit 1
fi

STATE="$RUN_DIR/$WG_IFACE.state"
PAUSE="$RUN_DIR/$WG_IFACE.paused"
DISABLED="$RUN_DIR/disabled"
PROFILE_DISABLED="$WG_DIR/$WG_IFACE.disabled"

lock() {
  if command -v flock >/dev/null 2>&1; then
    flock "$@"
  else
    busybox flock "$@"
  fi
}

tun_registered() {
  grep -Eq '^[[:space:]]*200[[:space:]]+tun$' /proc/misc
}

prepare_tun() {
  if ! tun_registered && [ -f "$TUN_MODULE" ]; then
    insmod "$TUN_MODULE" || tun_registered || return 1
  fi
  tun_registered || error "TUN driver unavailable on kernel $(uname -r)" || return 1
  if [ ! -c /dev/net/tun ]; then
    mkdir -p /dev/net && mknod -m 600 /dev/net/tun c 10 200 || return 1
  fi
}

# Ignore zombies and compare start times before signaling a PID from disk.
process_start_time() {
  sed 's/^.*) //' "/proc/$1/stat" 2>/dev/null |
    awk '$1 != "Z" && $1 != "X" { print $20 }'
}

read_daemon() {
  [ -f "$STATE/process" ] || return 1
  read -r daemon_pid daemon_start < "$STATE/process" || return 1
  [ -n "$daemon_start" ] && [ "$(process_start_time "$daemon_pid")" = "$daemon_start" ]
}

terminate_daemon() {
  read_daemon || return 0
  kill -TERM "$daemon_pid" 2>/dev/null || true
  for attempt in 1 2 3 4 5; do
    read_daemon || return 0
    sleep 0.2
  done
  kill -KILL "$daemon_pid" 2>/dev/null || true
  for attempt in 1 2 3 4 5; do
    read_daemon || return 0
    sleep 0.2
  done
  error "Could not stop wireguard-go (PID $daemon_pid)"
}

# Replace the symlink target atomically, keeping the resolver's permissions.
# Compare against the expected contents so a DHCP update takes precedence.
replace_resolver() {
  target=$(readlink -f "$RESOLV_CONF") || return 1
  replacement=$(mktemp "${target}.wireguard.XXXXXX") || return 1
  if cp -p "$target" "$replacement" && cat "$1" > "$replacement"; then
    if ! cmp -s "$2" "$target"; then
      rm -f "$replacement"
      return 2
    fi
    if mv -f "$replacement" "$target"; then
      return 0
    fi
  fi
  rm -f "$replacement"
  return 1
}

restore_dns() {
  [ -f "$STATE/dns.applied" ] || return 0
  cmp -s "$STATE/dns.applied" "$RESOLV_CONF" || return 0
  replace_resolver "$STATE/dns.original" "$STATE/dns.applied"
  result=$?
  [ "$result" -eq 0 ] || [ "$result" -eq 2 ] || error "Could not restore $RESOLV_CONF"
}

stop_tunnel() {
  [ -d "$STATE" ] || return 0
  terminate_daemon || return 1
  restore_dns || return 1
  # Closing the TUN file descriptor removes the interface and its kernel routes.
  rm -rf "$STATE"
}

read_list() {
  [ -f "$1" ] || return 0
  awk '{ sub(/#.*/, ""); sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if ($0 != "") print }' "$1"
}

family_of() {
  case "$1" in
    *:*) printf '%s\n' -6 ;;
    *) printf '%s\n' -4 ;;
  esac
}

add_address() {
  case "$1" in
    */*) ;;
    *) error "Expected an address in CIDR notation: $1"; return 1 ;;
  esac
  ip "$(family_of "$1")" address add "$1" dev "$WG_IFACE"
}

add_route() {
  case "$1" in
    */*) ;;
    *) error "Expected a route in CIDR notation: $1"; return 1 ;;
  esac
  family=$(family_of "$1")
  # An address can already have installed the exact connected route.
  existing=$(ip "$family" route show dev "$WG_IFACE" exact "$1") || return 1
  [ -n "$existing" ] || ip "$family" route add "$1" dev "$WG_IFACE"
}

check_endpoint_routes() {
  timeout 2 wg show "$WG_IFACE" endpoints > "$STATE/endpoints" || return 1
  while read -r _ endpoint; do
    case "$endpoint" in
      \[*\]:*) host=${endpoint%%\]*}; host=${host#\[} ;;
      *:*) host=${endpoint%:*} ;;
      *) continue ;;
    esac
    path=$(ip "$(family_of "$host")" route get "$host") || return 1
    if printf '%s\n' "$path" | awk -v tunnel="$WG_IFACE" '
      { for (f = 1; f < NF; f++) if ($f == "dev" && $(f+1) == tunnel) found = 1 }
      END { exit !found }
    '; then
      error "Route to endpoint $host points into $WG_IFACE"
      return 1
    fi
  done < "$STATE/endpoints"
}

apply_dns() {
  [ -s "$STATE/dns" ] || return 0
  for applied in "$RUN_DIR"/*.state/dns.applied; do
    if [ -f "$applied" ]; then
      error "Another WireGuard interface already manages $RESOLV_CONF"
      return 1
    fi
  done

  while IFS= read -r server; do
    case "$server" in
      *[!a-fA-F0-9:.]*) error "Invalid DNS server: $server"; return 1 ;;
    esac
    case "$server" in
      *.*|*:*) ;;
      *) error "Expected an IP address for DNS: $server"; return 1 ;;
    esac
    ip "$(family_of "$server")" route get "$server" >/dev/null || return 1
    printf 'nameserver %s\n' "$server" || return 1
  done < "$STATE/dns" > "$STATE/dns.pending" || return 1

  cp "$RESOLV_CONF" "$STATE/dns.original" || return 1
  mv "$STATE/dns.pending" "$STATE/dns.applied" || return 1
  replace_resolver "$STATE/dns.applied" "$STATE/dns.original" ||
    error "Could not set $RESOLV_CONF (the resolver may have changed during setup)"
}

daemon_ready() {
  read_daemon && timeout 2 wg show "$WG_IFACE" listen-port >/dev/null 2>&1
}

tunnel_ready() {
  [ -f "$STATE/ready" ] &&
    [ -n "$(ip link show up dev "$WG_IFACE" 2>/dev/null)" ] &&
    daemon_ready
}

configure_tunnel() {
  for suffix in addresses routes dns; do
    if ! read_list "$WG_DIR/$WG_IFACE.$suffix" > "$STATE/$suffix"; then
      error "Could not read $WG_IFACE.$suffix"
      return 1
    fi
  done
  if grep -Eq '^(default|[^/]+/0+)$' "$STATE/routes"; then
    error "Default routes require full-tunnel policy routing. Use explicit remote subnets in $WG_IFACE.routes."
    return 1
  fi
  if [ ! -s "$STATE/addresses" ]; then
    printf 'WireGuard (%s): no tunnel addresses configured in %s.addresses\n' "$WG_IFACE" "$WG_IFACE" >&2
  fi
  prepare_tun || return 1

  setsid wireguard-go -f "$WG_IFACE" </dev/null > "/$WG_IFACE-wireguard-go.log" 2>&1 8>&- 9>&- &
  daemon_pid=$!
  daemon_start=$(process_start_time "$daemon_pid")
  if [ -z "$daemon_start" ]; then
    error "wireguard-go exited during startup. See /$WG_IFACE-wireguard-go.log"
    return 1
  fi
  if ! printf '%s %s\n' "$daemon_pid" "$daemon_start" > "$STATE/process"; then
    kill -TERM "$daemon_pid" 2>/dev/null || true
    return 1
  fi

  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    daemon_ready && break
    read_daemon || break
    sleep 0.5
  done
  daemon_ready || error "Control socket unavailable. See /$WG_IFACE-wireguard-go.log" || return 1

  WG_ENDPOINT_RESOLUTION_RETRIES=0 timeout 12 wg setconf "$WG_IFACE" "$WG_DIR/$WG_IFACE.conf" || return 1
  while IFS= read -r address; do
    add_address "$address" || return 1
  done < "$STATE/addresses"
  ip link set dev "$WG_IFACE" up || return 1

  while IFS= read -r route; do
    add_route "$route" || return 1
  done < "$STATE/routes"
  check_endpoint_routes || return 1
  apply_dns || return 1
  daemon_ready || error "wireguard-go exited during configuration"
}

start_tunnel() {
  [ -f "$WG_DIR/$WG_IFACE.conf" ] || error "Missing $WG_DIR/$WG_IFACE.conf" || return 1
  stop_tunnel || return 1
  if ip link show dev "$WG_IFACE" >/dev/null 2>&1; then
    error "Interface exists outside this service. Stop the process that owns it first."
    return 1
  fi
  mkdir "$STATE" || return 1
  if configure_tunnel &&
    printf '%s\n' "$1" > "$STATE/uplink" &&
    touch "$STATE/ready"; then
    return 0
  fi
  stop_tunnel
  return 1
}

uplink_signature() {
  {
    ip -4 route show default
    ip -6 route show default
  } 2>/dev/null | awk -v tunnel="$WG_IFACE" '
    $1 == "default" && $0 !~ /(^| )linkdown( |$)/ {
      dev = ""; gateway = "-"; metric = 0
      for (f = 1; f < NF; f++) {
        if ($f == "dev") dev = $(f+1)
        else if ($f == "via") gateway = $(f+1)
        else if ($f == "metric") metric = $(f+1)
      }
      # Keep the route identity stable as DHCP and IPv6 route lifetimes count down.
      if (dev != "" && dev != "lo" && dev != tunnel) print dev, gateway, metric
    }
  ' | sort -u | while read -r device route; do
    if [ -e "/sys/class/net/$device/carrier" ]; then
      IFS= read -r carrier 2>/dev/null < "/sys/class/net/$device/carrier" || continue
      [ "$carrier" = 1 ] || continue
    fi
    addresses=$(ip address show dev "$device" 2>/dev/null |
      awk '$1 == "inet" || ($1 == "inet6" && /scope global/) { print $2 }' | sort)
    [ -n "$addresses" ] && printf '%s %s\n' "$route" "$addresses"
  done
}

watch_step() {
  if [ -f "$PROFILE_DISABLED" ] || [ ! -f "$WG_DIR/$WG_IFACE.conf" ]; then
    stop_tunnel
    return $?
  fi
  uplink=$(uplink_signature)
  previous=$(cat "$STATE/uplink" 2>/dev/null)
  if [ -f "$PAUSE" ]; then
    [ -n "$uplink" ] && [ "$uplink" = "$(cat "$PAUSE")" ] && return 0
    rm -f "$PAUSE" || return 1
  fi
  if [ -z "$uplink" ] && [ -n "$previous" ]; then
    stop_tunnel
  elif [ -n "$uplink" ] && { [ "$uplink" != "$previous" ] || ! tunnel_ready; }; then
    start_tunnel "$uplink" > "$RUN_DIR/$WG_IFACE.setup.log" 2>&1
  fi
}

watch() {
  exec 8>"$RUN_DIR/watch.lock"
  lock -n 8 || return 0
  while :; do
    lock -x 9 || return 1
    [ ! -f "$DISABLED" ] || return 0
    watch_step
    lock -u 9 || return 1
    sleep 5
  done
}

show_status() {
  if [ -f "$DISABLED" ] || [ -f "$PROFILE_DISABLED" ]; then
    printf 'WireGuard is off.\n'
  elif [ -f "$PAUSE" ]; then
    printf 'WireGuard is paused until the next reconnect.\n'
  elif [ ! -f "$WG_DIR/$WG_IFACE.conf" ]; then
    printf 'WireGuard profile %s.conf is missing.\n' "$WG_IFACE"
  elif tunnel_ready; then
    printf 'WireGuard is up (%s).\n' "$WG_IFACE"
    if handshakes=$(timeout 2 wg show "$WG_IFACE" latest-handshakes 2>/dev/null); then
      printf '%s\n' "$handshakes" | awk -v now="$(date +%s)" '
        $2 > last { last = $2 }
        END {
          if (!last) print "No peer handshake yet."
          else if (last > now) print "A peer handshake was recorded."
          else printf "Last peer handshake: %d seconds ago.\n", now - last
        }
      '
    else
      printf 'Peer handshake status unavailable.\n'
    fi
  elif [ -z "$(uplink_signature)" ]; then
    printf 'WireGuard is enabled and waiting for Wi-Fi.\n'
  else
    printf 'WireGuard is enabled and waiting for setup.\nLog: %s/%s.setup.log\n' "$RUN_DIR" "$WG_IFACE"
  fi
}

toggle_profile() {
  [ ! -f "$DISABLED" ] || error "Service is disabled" || return 1
  if [ -f "$PROFILE_DISABLED" ] || [ -f "$PAUSE" ]; then
    rm -f "$PROFILE_DISABLED" "$PAUSE" || return 1
    printf 'WireGuard enabled. It will start when Wi-Fi is ready.\n'
  else
    touch "$PROFILE_DISABLED" || return 1
    stop_tunnel || return 1
    printf 'WireGuard turned off.\n'
  fi
}

mkdir -p "$RUN_DIR" || exit 1
cd / || exit 1
exec 9>"$RUN_DIR/service.lock"

if [ "$1" = watch ]; then
  watch
  exit $?
fi

case "$1" in
  status|toggle)
    if ! lock -n 9; then
      printf 'WireGuard is busy. Try again in a moment.\n'
      exit 0
    fi
    ;;
  *)
    lock -x 9 || { error "Could not lock the service (flock is required)"; exit 1; }
    ;;
esac
case "$1" in
  start)
    [ ! -f "$DISABLED" ] || { error "Service is disabled"; exit 1; }
    rm -f "$PAUSE" "$PROFILE_DISABLED" || exit 1
    if tunnel_ready; then
      exit 0
    fi
    start_tunnel "$(uplink_signature)"
    ;;
  stop)
    uplink_signature > "$PAUSE" || exit 1
    stop_tunnel
    ;;
  status)
    show_status
    ;;
  toggle)
    toggle_profile
    ;;
  enable)
    rm -f "$DISABLED" "$PAUSE"
    ;;
  shutdown)
    touch "$DISABLED" || exit 1
    for STATE in "$RUN_DIR"/*.state; do
      [ -d "$STATE" ] || continue
      stop_tunnel || exit 1
    done
    lock -u 9 || exit 1
    exec 8>"$RUN_DIR/watch.lock"
    lock -x 8
    ;;
  *)
    error "Expected start, stop, status, toggle, watch, enable, or shutdown"
    ;;
esac
