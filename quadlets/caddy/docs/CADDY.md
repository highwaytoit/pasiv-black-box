# Caddy on Pasiv Black Box

Caddy is the HTTPS ingress for selected human-facing monitoring applications. The tested deployment uses the Pasiv private monitoring network, Cloudflare DNS-01, persistent storage, SELinux enforcing, and a Tailscale-only host bind.

## Tested template

`/usr/share/pasiv-black-box/quadlets/caddy/caddy.container`

Image:

`ghcr.io/highwaytoit/caddy-cloudflare-build:latest`

Validated with upstream Caddy v2.11.4.

## Local paths

```text
/etc/caddy/Caddyfile
/etc/pasiv-black-box/caddy/caddy.env
/var/mnt/monitoring/caddy/data
/var/mnt/monitoring/caddy/config
```

Store the Cloudflare token only in the root-owned environment file:

```text
CF_API_TOKEN=REPLACE_WITH_YOUR_TOKEN
```

Recommended mode is `0600`.

## SELinux

For the default monitoring storage layout:

```bash
sudo semanage fcontext -a -t container_file_t '/var/mnt/monitoring/caddy(/.*)?'
sudo restorecon -RFv /var/mnt/monitoring/caddy
```

If the rule already exists, modify it instead of adding a duplicate.

## Minimal DNS-01 test

```caddyfile
{
    acme_dns cloudflare {env.CF_API_TOKEN}
}

caddy-bbox.example.com {
    respond "Pasiv Black Box Caddy OK" 200
}
```

The supplied Quadlet uses a sample Tailscale address on host port 8443. Replace that address with the appliance's actual Tailscale IPv4 before activation.

## Deploy

```bash
sudo cp \
  /usr/share/pasiv-black-box/quadlets/caddy/caddy.container \
  /etc/containers/systemd/caddy.container
sudo systemctl daemon-reload
sudo systemctl start caddy.service
```

Validate with `systemctl status caddy.service`, `podman ps`, the Caddy journal, and an HTTPS request from an allowed Tailscale client.

The tested deployment survived a full host reboot with persistent certificates and zero failed systemd units.
