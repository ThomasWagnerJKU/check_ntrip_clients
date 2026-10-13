# check_ntrip_clients

Nagios/Icinga/Checkmk (OMD) plugin that checks how many clients are connected
to a local NTRIP caster, e.g. RTKLIB `str2str` with an `ntripc://` output as
used by [RTKBase](https://github.com/Stefal/rtkbase).

## Why

`str2str` accepts at most 32 clients per caster. Clients that connect without
sending a valid NTRIP request (port scanners, broken clients) are never timed
out, so they hold a slot forever. Once all 32 slots are taken, new clients,
including real rovers, can no longer connect. The kernel's listen queue then
fills up and further connections are dropped.

The caster service keeps running throughout, so a service or process check
stays green while no rover gets corrections. This plugin detects that
situation.

## What is checked

| Value     | Meaning                                                                 |
|-----------|-------------------------------------------------------------------------|
| `clients` | Connections accepted by the caster process on the port                  |
| `stale`   | Accepted clients that were not sent any data for longer than `-a` seconds. Served rovers get data every second, so these are usually scanners holding a slot. Reported only. |
| `backlog` | Connections waiting in the kernel listen queue                          |

States:

- **CRITICAL**: `clients` >= critical threshold, the listen queue is full, or
  nothing is listening on the port
- **WARNING**: `clients` >= warning threshold
- **UNKNOWN**: invalid arguments, `ss` missing, or insufficient privileges

Example output:

```
CRITICAL: 32/32 clients connected, 32 stale (no data for >300s), listen queue full (6/5) - new clients are rejected | clients=32;24;30;0;32 stale=32;;;0;32 backlog=6;;5;0;
```

## Usage

```
check_ntrip_clients [-p <port>] [-w <warning>] [-c <critical>] [-m <max>] [-a <seconds>]

  -p <port>      TCP port of the NTRIP caster (default: 8080)
  -w <warning>   Warning threshold for connected clients (default: 24)
  -c <critical>  Critical threshold for connected clients (default: 30)
  -m <max>       Maximum number of clients of the caster (default: 32)
  -a <seconds>   Clients without data sent for this long count as stale (default: 300)
  -h             Show this help message
```

## Requirements

- bash
- `ss` from iproute2
- Privileges to see the owner of the caster's sockets (`ss -p`): the plugin
  must run as root or as the user running the caster. Otherwise it returns
  UNKNOWN. Connections that are still in the listen queue are not owned by
  any process yet, and this is how they are told apart from accepted clients.

## Installation

```
make check                # syntax check of plugin and sudoers file
sudo make install         # /usr/lib/nagios/plugins/check_ntrip_clients
sudo make install-sudoers # /etc/sudoers.d/check_ntrip_clients
```

### Monitoring user

The monitoring server logs in via SSH as an unprivileged user and runs the
plugin through `sudo`. The included `sudoers.d/check_ntrip_clients` allows the
user `nagios` to run exactly this plugin as root without a password. Edit the
user name in that file before installing if yours differs.

1. Create the user (Debian / Raspberry Pi OS):

   ```
   sudo adduser --system --group --home /var/lib/nagios --shell /bin/sh nagios
   ```

2. Allow SSH login with the monitoring server's public key only, restricted to
   its address:

   ```
   sudo install -d -o nagios -g nagios -m 0700 /var/lib/nagios/.ssh
   echo 'from="<monitoring-server-ip>",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty <public-key>' \
       | sudo tee /var/lib/nagios/.ssh/authorized_keys
   sudo chown nagios:nagios /var/lib/nagios/.ssh/authorized_keys
   sudo chmod 0600 /var/lib/nagios/.ssh/authorized_keys
   ```

   If a firewall (e.g. ufw) is active, SSH must be allowed from the monitoring
   server.

3. Install the sudoers file (`sudo make install-sudoers`) and test as that
   user:

   ```
   sudo -u nagios sudo -n /usr/lib/nagios/plugins/check_ntrip_clients
   ```

Every check is logged to the auth log by sudo. To suppress that, uncomment the
`Defaults!CHECK_NTRIP_CLIENTS !log_allowed` line in the sudoers file.

### Monitoring server

Run the plugin with `check_by_ssh` (sudo must be called with `-n` so it fails
instead of prompting):

```
check_by_ssh -H <host> -l nagios \
    -C 'sudo -n /usr/lib/nagios/plugins/check_ntrip_clients -p 8080 -w 24 -c 30'
```

## Clearing the slots

The plugin only detects the problem. To free the slots, restart the caster
(RTKBase: `sudo systemctl restart str2str_local_ntrip_caster`). To keep them
from filling up again, restrict access to the caster port to the networks your
rovers use.

## License

Copyright (C) 2026 Thomas Wagner <thomas.wagner@jku.at>

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version. See [COPYING](COPYING) for the full text.
