# OpenClaw

OpenClaw provides a request-driven diagnostic assistant for a Pasiv Black Box monitoring node. This module uses `ghcr.io/openclaw/openclaw:latest`, the rootful `pasiv-monitoring.network`, and the image's unprivileged `node` user (UID/GID 1000).

The supplied baseline is intentionally limited. The Gateway listens on the private container network so approved services such as n8n can use its authenticated API, but it publishes no host port. The container drops all Linux capabilities, enables `no-new-privileges`, disables elevated tools and browser control, and prevents the running application from changing its configuration. Telegram direct messages are restricted to one numeric owner ID, groups are disabled, and background heartbeat, dreaming, and Skill Workshop activity are disabled.

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
sudo semanage fcontext -a -t container_file_t '/mnt/monitoring/openclaw(/.*)?'
sudo semanage fcontext -a -t container_file_t '/mnt/monitoring/openclaw-auth(/.*)?'
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
sudo systemctl start openclaw.service
```

Do not run `systemctl enable openclaw.service`. Quadlet generates the service at runtime, and its `[Install]` section creates the boot dependency automatically.

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

The Control UI is not reverse-proxied or published. Do not add trusted proxies solely for n8n: n8n authenticates directly to the Gateway over the private container network. Do not publish the Gateway on a host port unless its trust boundary is redesigned first.

## n8n and subscription-included Codex

The n8n module can use OpenClaw as an OpenAI-compatible model endpoint at:

`http://openclaw:18789/v1`

This requires the authenticated Chat Completions endpoint enabled in the supplied JSON example and the Gateway's `lan` bind. The endpoint remains private because the Quadlet publishes no host port.

Use the existing `OPENCLAW_GATEWAY_TOKEN` as the API key in n8n. This is a local bearer token, not an OpenAI Platform API key. OpenClaw continues to authenticate to Codex through OAuth, so no separate external paid AI API account or usage-billed API key is required. Requests consume the normal Codex allowance included with the operator's eligible ChatGPT subscription.

The validated read-only pattern collects fixed monitoring evidence in n8n first and sends that evidence to OpenClaw for explanation. OpenClaw receives no Podman socket, systemd interface, host mount, or write-capable monitoring tool.

See `../../n8n/docs/N8N.md` for the complete workflow.

## Access boundary

This baseline does not mount the host filesystem, Podman socket, systemd interfaces, journal, or monitoring data. It therefore cannot inspect those resources directly. Direct host inspection remains unavailable. The validated n8n integration can instead collect fixed read-only monitoring responses and provide that evidence to OpenClaw for analysis.

## Physical validation

This module was validated on physical Pasiv Black Box hardware with the OpenClaw Gateway health endpoint, service restart recovery, Codex OAuth, the selected model, owner-only Telegram polling and response, hardened runtime settings, zero scheduled automations, private n8n-to-OpenClaw connectivity, authenticated model discovery, and a successful read-only Prometheus health workflow. A full host reboot has not yet been validated for this module.
