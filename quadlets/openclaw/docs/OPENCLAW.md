# OpenClaw

OpenClaw provides a request-driven diagnostic assistant for a Pasiv Black Box monitoring node. This module uses `ghcr.io/openclaw/openclaw:latest`, the rootful `pasiv-monitoring.network`, and the image's unprivileged `node` user (UID/GID 1000).

The supplied baseline is intentionally limited. The Gateway listens only on container loopback, publishes no host port, drops all Linux capabilities, enables `no-new-privileges`, disables elevated tools and browser control, and prevents the running application from changing its configuration. Telegram direct messages are restricted to one numeric owner ID, groups are disabled, and background heartbeat, dreaming, and Skill Workshop activity are disabled.

## Files and storage

| Host path | Container path | Purpose |
| --- | --- | --- |
| `/var/mnt/monitoring/openclaw` | `/home/node/.openclaw` | Configuration, agent state, and workspace |
| `/var/mnt/monitoring/openclaw-auth` | `/home/node/.config/openclaw` | Provider authentication state |
| `/etc/pasiv-black-box/openclaw/openclaw.env` | Environment file | Gateway and Telegram secrets |

Create the directories with permissions suitable for the image's UID/GID 1000:

```bash
sudo install -d -m 0700 -o 1000 -g 1000 /var/mnt/monitoring/openclaw
sudo install -d -m 0700 -o 1000 -g 1000 /var/mnt/monitoring/openclaw-auth
sudo install -d -m 0700 -o root -g root /etc/pasiv-black-box/openclaw
```

Apply persistent SELinux labels:

```bash
sudo semanage fcontext -a -t container_file_t '/var/mnt/monitoring/openclaw(/.*)?'
sudo semanage fcontext -a -t container_file_t '/var/mnt/monitoring/openclaw-auth(/.*)?'
sudo restorecon -RFv /var/mnt/monitoring/openclaw
sudo restorecon -RFv /var/mnt/monitoring/openclaw-auth
sudo restorecon -RFv /etc/pasiv-black-box/openclaw
```

If an SELinux rule already exists, use `semanage fcontext -m` instead of `-a`.

## Configure the secure baseline

Install the sanitized configuration example:

```bash
sudo install -m 0600 -o 1000 -g 1000 \
  /usr/share/pasiv-black-box/quadlets/openclaw/examples/openclaw.json.example \
  /var/mnt/monitoring/openclaw/openclaw.json
```

Replace `REPLACE_WITH_NUMERIC_TELEGRAM_USER_ID` in both locations with the owner's numeric Telegram user ID. Keep the allowlist restricted to that ID. The example selects `openai/gpt-5.6-sol`; change it only if a different available Codex model is intended.

Create the environment file without placing either secret in shell history:

```bash
sudo bash -c '
set -euo pipefail
umask 077
env_file=/etc/pasiv-black-box/openclaw/openclaw.env
read -rsp "Telegram bot token: " telegram_token
printf "\n"
gateway_token=$(openssl rand -hex 32)
printf "OPENCLAW_GATEWAY_TOKEN=%s\nTELEGRAM_BOT_TOKEN=%s\n" \
  "$gateway_token" "$telegram_token" > "$env_file"
unset gateway_token telegram_token
'
```

The file must remain owned by root with mode `0600`. Never commit real tokens, Telegram IDs, device codes, OAuth output, account names, domains, or private addresses.

## Connect Codex before starting the service

Use a temporary rootful container so OAuth state is written to the same persistent directories as the service:

```bash
openclaw_image=ghcr.io/openclaw/openclaw:latest
openclaw_run_args=(
  --rm -it
  --network pasiv-monitoring
  --env HOME=/home/node
  --env OPENCLAW_HOME=/home/node
  --env OPENCLAW_STATE_DIR=/home/node/.openclaw
  --env OPENCLAW_CONFIG_PATH=/home/node/.openclaw/openclaw.json
  --env OPENCLAW_CONFIG_DIR=/home/node/.openclaw
  --env OPENCLAW_WORKSPACE_DIR=/home/node/.openclaw/workspace
  --volume /var/mnt/monitoring/openclaw:/home/node/.openclaw:Z
  --volume /var/mnt/monitoring/openclaw-auth:/home/node/.config/openclaw:Z
)

sudo podman run "${openclaw_run_args[@]}" "$openclaw_image" \
  node openclaw.mjs models auth login --provider openai --device-code

sudo podman run "${openclaw_run_args[@]}" "$openclaw_image" \
  node openclaw.mjs models set openai/gpt-5.6-sol

unset openclaw_image openclaw_run_args
```

Complete the device login in a trusted local browser. Do not share the device code or authentication output.

## Install and start

```bash
sudo cp \
  /usr/share/pasiv-black-box/quadlets/openclaw/openclaw.container \
  /etc/containers/systemd/openclaw.container
sudo chown root:root /etc/containers/systemd/openclaw.container
sudo systemctl daemon-reload
sudo systemctl enable --now openclaw.service
```

Because `OPENCLAW_CONFIG_READONLY=1` is set, make later configuration changes in the host-side JSON while the service is stopped, validate the file, and then start the service again.

## Validate

```bash
sudo podman ps \
  --filter name=openclaw \
  --format 'name={{.Names}} status={{.Status}} ports={{.Ports}}'

sudo podman exec openclaw node -e \
  'fetch("http://127.0.0.1:18789/healthz").then(async response => { console.log("status=" + response.status); console.log(await response.text()); process.exit(response.ok ? 0 : 1); }).catch(error => { console.error(error); process.exit(1); })'

sudo podman exec openclaw node openclaw.mjs channels status --probe
sudo podman exec openclaw node openclaw.mjs security audit
sudo podman exec openclaw node openclaw.mjs automations list
```

With the Control UI kept on loopback, the audit warning about missing trusted reverse proxies is expected and does not require adding proxies. Do not reverse-proxy or publish the Gateway unless its trust boundary is redesigned first.

## Access boundary

This baseline does not mount the host filesystem, Podman socket, systemd interfaces, journal, or monitoring data. It therefore cannot inspect those resources directly. Monitoring-data integration and any final knowledge or operational configuration are intentionally deferred until the retained service set is decided.

## Physical validation

This module was validated on physical Pasiv Black Box hardware with the OpenClaw Gateway health endpoint, service restart recovery, Codex OAuth, the selected model, owner-only Telegram polling and response, hardened runtime settings, and zero scheduled automations. A full host reboot has not yet been validated for this module.
