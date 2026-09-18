# NUT and UPSide

NUT and UPSide are installed natively because UPS monitoring, host shutdown, USB device access, and power-state handling belong to the host operating system.

The generic image deliberately does not contain:

- UPS model or USB identifiers
- NUT usernames/passwords
- `ups.conf` hardware configuration
- shutdown thresholds or timers
- Wake-on-LAN targets
- site-specific notification or recovery policy

Those settings are deployment-specific and should be configured by the administrator after installation.

UPSide is built in a separate build stage and copied into `/usr/share/cockpit/upside/`. Build dependencies such as Node.js and npm do not remain in the final image.

A typical deployment can use Pasiv Black Box as a NUT server for a directly attached UPS, with other systems connecting as NUT clients over the network.

## Reboot-safe NUT service startup

NUT's service units are organized around `nut.target`:

- `nut-server.service` is wanted by `nut.target`
- `nut-monitor.service` is wanted by `nut.target`
- UPS driver instances are wanted by `nut-driver.target`, which is pulled in by `nut.target`

After configuring a local UPS with UPSide, verify that the top-level target is enabled:

```bash
systemctl is-enabled nut.target
```

If it is disabled, enable and start it:

```bash
sudo systemctl enable --now nut.target
```

This is intentionally a deployment step rather than an image default. Pasiv Black Box cannot assume that every installation has a local UPS configured.

### Network server mode

When `upsd.conf` contains a `LISTEN` directive for a specific LAN address, `upsd` can fail during boot if it starts before that address is available. The typical log sequence is:

```text
not listening on <LAN-IP> port 3493
Reconcile available NUT server IP addresses and LISTEN configuration
Fatal error: some listening interfaces were not available
```

Pasiv Black Box ships a systemd drop-in for `nut-server.service` that adds:

```ini
[Unit]
Wants=network-online.target
After=network-online.target
```

This preserves explicit NUT listener configuration while ensuring `upsd` starts only after the host network is considered online.

## UPSide history requirements

UPSide historical charts use Performance Co-Pilot (PCP). Pasiv Black Box includes the focused package set required for this integration:

- `pcp`
- `pcp-pmda-openmetrics`
- `pcp-system-tools`

`pcp-system-tools` is required because UPSide reads local PCP archives with `pmrep`.

The OpenMetrics PMDA must also be registered before UPSide can configure NUT history. On AlmaLinux this can be done with:

```bash
cd /var/lib/pcp/pmdas/openmetrics
sudo ./Install
```

After registration, UPSide can install its NUT OpenMetrics scraper and the pmlogger rule from the History collection settings page.

Do not publish deployment-specific UPS serial numbers, NUT credentials, private addresses, or site topology in reusable configuration examples.
