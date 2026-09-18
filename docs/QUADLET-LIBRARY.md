# Pasiv Black Box Quadlet library

The image ships a reusable library of inactive system Quadlet templates under `/usr/share/pasiv-black-box/quadlets/`. Nothing in this library starts automatically.

| Module | Template | Documentation | Example configuration |
| --- | --- | --- | --- |
| Cockpit | `cockpit/cockpit.container` | `cockpit/docs/COCKPIT.md` | - |
| Monitoring network | `network/pasiv-monitoring.network` | `network/docs/NETWORK.md` | - |
| Caddy | `caddy/caddy.container` | `caddy/docs/CADDY.md` | local `Caddyfile` + env file |
| Authelia | `authelia/authelia.container` | `authelia/docs/AUTHELIA.md` | documented local config/secrets |
| Uptime Kuma | `uptime-kuma/uptime-kuma.container` | `uptime-kuma/docs/UPTIME-KUMA.md` | local persistent data directory |
| OpenClaw | `openclaw/openclaw.container` | `openclaw/docs/OPENCLAW.md` | `openclaw/examples/openclaw.json.example` + `openclaw.env.example` |
| n8n | `n8n/n8n.container` | `n8n/docs/N8N.md` | `n8n/examples/n8n.env.example` |
| Grafana | `grafana/grafana.container` | `grafana/docs/GRAFANA.md` | documented local env file |
| Prometheus | `prometheus/prometheus.container` | `prometheus/docs/PROMETHEUS.md` | `prometheus/examples/prometheus.yml` |
| Blackbox Exporter | `blackbox-exporter/blackbox-exporter.container` | `blackbox-exporter/docs/BLACKBOX-EXPORTER.md` | `blackbox-exporter/examples/blackbox.yml` |
| SNMP Exporter | `snmp-exporter/snmp-exporter.container` | `snmp-exporter/docs/SNMP-EXPORTER.md` | `snmp-exporter/examples/snmp-auth.yml` + `snmp.env.example` |
| Node Exporter | `node-exporter/node-exporter.container` | `node-exporter/docs/NODE-EXPORTER.md` | `node-exporter/examples/prometheus-job.yml` |
| NUT Exporter | `nut-exporter/nut-exporter.container` | `nut-exporter/docs/NUT-EXPORTER.md` | `nut-exporter/examples/prometheus-job.yml` |
| Loki | `loki/loki.container` | `loki/docs/LOKI.md` | documented local config |
| Grafana Alloy | `alloy/alloy.container` | `alloy/docs/ALLOY.md` | documented local config |
| VictoriaMetrics | `victoriametrics/victoriametrics.container` | `victoriametrics/docs/VICTORIAMETRICS.md` | - |
| Alertmanager | `alertmanager/alertmanager.container` | `alertmanager/docs/ALERTMANAGER.md` | `alertmanager/examples/alertmanager.yml` |

## Intended use

1. Read the service documentation.
2. Copy the required template and any example configuration to local administrator-owned paths.
3. Replace examples/placeholders and add deployment-specific secrets locally.
4. Apply the documented storage ownership and SELinux labels.
5. Run `systemctl daemon-reload` and start the generated service.
6. Validate the service before enabling or depending on it.

The monitoring application templates in this library were derived from configurations validated on a real Pasiv Black Box deployment, including restart and host reboot testing. The public versions are sanitized and do not contain deployment domains, credentials, tokens, account names, private chat IDs, or site-specific addresses.

Cockpit has also been explicitly revalidated on physical Pasiv Black Box hardware with the supplied Quadlet unchanged, including local-SSH authentication, administrative access, Files, Podman, Storage, UPSide, Terminal, and automatic recovery after a host reboot.

Blackbox Exporter has been explicitly validated on physical Pasiv Black Box hardware with HTTP/HTTPS, TCP, ICMP, and DNS probes, Prometheus integration over the private monitoring network, and automatic recovery after a full host reboot.

SNMP Exporter has been explicitly validated on physical Pasiv Black Box hardware with SNMPv3 `authPriv`, the upstream `system`, `if_mib`, and `mikrotik` modules, Prometheus integration over the private monitoring network, exporter restart recovery, and automatic recovery after a full host reboot.

Node Exporter has been explicitly validated on physical Pasiv Black Box hardware with host CPU, memory, filesystems, disk I/O and udev metadata, network counters, hardware temperatures, Prometheus integration over a private host-bridge listener, exporter restart recovery, and automatic recovery after a full host reboot.

NUT Exporter has been explicitly validated on physical Pasiv Black Box hardware against a local NUT server, including battery, runtime, voltage, load, and status metrics; private host-bridge binding; Prometheus and VictoriaMetrics integration; hardware-identity metadata disabled; and automatic recovery of the complete metrics path after a full host reboot.

Uptime Kuma has been explicitly validated on physical Pasiv Black Box hardware with HTTP, TCP, and ICMP Ping monitors; Embedded MariaDB persistence on local storage; no published host port; Caddy reverse proxying over the private monitoring network; Authelia protection; and automatic recovery of all monitors after a full host reboot.

OpenClaw has been explicitly validated on physical Pasiv Black Box hardware with Codex OAuth, the `openai/gpt-5.6-sol` model, owner-only Telegram polling, an internal health response, service restart recovery, private-network Gateway binding, no published host port, authenticated n8n model access, all Linux capabilities dropped, `no-new-privileges`, read-only application configuration, browser and elevated modes disabled, and no scheduled automations. Full reboot validation is intentionally deferred.

n8n has been explicitly validated on physical Pasiv Black Box hardware with SQLite persistence, no published host port, private Caddy connectivity, Tailscale-only HTTPS, Authelia protection, service restart recovery, an OpenClaw-backed OpenAI credential, and a deterministic read-only Prometheus health workflow. The integration uses the existing OpenClaw Gateway token and Codex OAuth instead of a separate paid model API key. Full host reboot validation is intentionally deferred.

The library is intentionally modular so individual service directories can later be moved to a shared repository without changing their internal layout.
