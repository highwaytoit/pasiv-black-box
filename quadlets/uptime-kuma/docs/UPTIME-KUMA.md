# Uptime Kuma on Pasiv Black Box

Uptime Kuma provides simple availability monitoring for services and devices. Pasiv Black Box supplies an inactive Quadlet template derived from a deployment validated on physical hardware.

## Tested image

`docker.io/louislam/uptime-kuma:2`

## Files and storage

Template:

`/usr/share/pasiv-black-box/quadlets/uptime-kuma/uptime-kuma.container`

Persistent data:

`/var/mnt/monitoring/uptime-kuma`

The host directory is mounted at `/app/data` inside the container. During the validated first-run setup, Embedded MariaDB was selected. Its database, Uptime Kuma settings, users, and monitor definitions all persist inside `/app/data`.

Keep `/app/data` on local storage. Do not place the live Uptime Kuma database on NFS or another network filesystem.

For the default monitoring storage layout:

```bash
sudo semanage fcontext -a -t container_file_t \
  '/var/mnt/monitoring/uptime-kuma(/.*)?'
sudo restorecon -RFv /var/mnt/monitoring/uptime-kuma
```

If the SELinux rule already exists, modify it instead of adding a duplicate.

## Network model

Uptime Kuma joins the private `pasiv-monitoring` Podman network with the alias `uptime-kuma`. Other containers on that network can reach it at:

`uptime-kuma:3001`

The supplied Quadlet publishes no host port. Caddy can proxy Uptime Kuma over the private container network without exposing port 3001 on the host.

## Ping capability

The template adds only:

`CAP_NET_RAW`

Uptime Kuma requires this capability for ICMP Ping monitors. HTTP and TCP monitors do not require a published host port or additional container capabilities.

## Reverse proxy with external authentication

A sanitized Caddy example using Authelia forward authentication is:

```caddyfile
uptime.example.com {
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://auth.example.com
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }

    reverse_proxy uptime-kuma:3001
}
```

Both Caddy and Authelia must join `pasiv-monitoring` with their documented network aliases. Replace the example domains only in the local administrator-owned Caddy and Authelia configuration.

## Deploy

Create the persistent directory, apply its SELinux label, copy the template, reload systemd, and start the generated service:

```bash
sudo install -d -m0750 /var/mnt/monitoring/uptime-kuma
sudo restorecon -RFv /var/mnt/monitoring/uptime-kuma
sudo cp \
  /usr/share/pasiv-black-box/quadlets/uptime-kuma/uptime-kuma.container \
  /etc/containers/systemd/uptime-kuma.container
sudo systemctl daemon-reload
sudo systemctl start uptime-kuma.service
```

Validate the service with `systemctl status uptime-kuma.service`, `podman ps`, the Uptime Kuma journal, and an authenticated HTTPS request through Caddy.

## Validation

This design was validated on physical Pasiv Black Box hardware with SELinux enforcing. Validation covered:

- HTTP, TCP, and ICMP Ping monitors;
- `CAP_NET_RAW` enabling Ping without adding broader privileges;
- no published host port for Uptime Kuma;
- private access from Caddy at `uptime-kuma:3001`;
- protection by Authelia;
- persistence of Embedded MariaDB data and all three monitors after a service restart;
- automatic recovery of Uptime Kuma, Caddy, Authelia, and the monitoring stack after a full host reboot;
- all three monitors returning to UP after reboot;
- zero failed systemd units after reboot.
