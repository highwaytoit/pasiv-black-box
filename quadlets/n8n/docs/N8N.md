# n8n on Pasiv Black Box

n8n provides workflow automation for Pasiv Black Box. The supplied module runs on the private monitoring network with no published host port and keeps its SQLite database, credentials, workflows, and settings on local persistent storage.

## Tested image

`docker.io/n8nio/n8n:latest`

The physical validation used n8n 2.38.7. The template intentionally follows the moving `latest` tag so routine container updates can deliver upstream security fixes.

## No separate paid AI API

The validated AI integration does not require an OpenAI Platform API key, a separate model-provider account, or usage-billed API configuration.

n8n connects to the local OpenClaw Gateway. OpenClaw authenticates to Codex with OAuth and uses the Codex access included with the operator's eligible ChatGPT subscription:

```text
n8n -> local OpenClaw Gateway -> Codex OAuth -> subscription Codex allowance
```

The value entered into the n8n OpenAI credential is the locally generated `OPENCLAW_GATEWAY_TOKEN`. It protects the private OpenClaw endpoint; it is not an OpenAI API key and does not create separate API billing. Requests still count against the ChatGPT plan's normal Codex usage allowance.

Current OpenAI plan and usage details are documented at:

https://learn.chatgpt.com/docs/pricing

## Files and storage

| Host path | Container path | Purpose |
| --- | --- | --- |
| `/var/mnt/monitoring/n8n` | `/home/node/.n8n` | SQLite database, credentials, workflows, and settings |
| `/etc/pasiv-black-box/n8n/n8n.env` | Environment file | Encryption key and deployment settings |

Create the directories for the image's unprivileged `node` user (UID/GID 1000):

```bash
sudo install -d -m 0700 -o 1000 -g 1000 /var/mnt/monitoring/n8n
sudo install -d -m 0700 -o root -g root /etc/pasiv-black-box/n8n
```

On the default AlmaLinux storage layout, SELinux maps `/var/mnt` to `/mnt`. Define the persistent rule with the canonical `/mnt` path, then relabel the actual storage path:

```bash
sudo semanage fcontext -a -t container_file_t '/mnt/monitoring/n8n(/.*)?'
sudo restorecon -RFv /var/mnt/monitoring/n8n
```

If the rule already exists, use `semanage fcontext -m` instead of `-a`.

Keep the live SQLite database on local storage rather than NFS or another network filesystem.

## Create the environment file

Use the HTTPS hostname served by the local Caddy instance. Enter only the hostname, without `https://`, a port, or a path:

```bash
sudo bash -c '
set -euo pipefail
umask 077
env_file=/etc/pasiv-black-box/n8n/n8n.env

read -rp "n8n HTTPS hostname, without https:// or port: " n8n_host
if [[ ! "$n8n_host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
    echo "Invalid hostname" >&2
    exit 1
fi

encryption_key=$(openssl rand -hex 32)

printf "%s\n" \
  "N8N_ENCRYPTION_KEY=${encryption_key}" \
  "N8N_HOST=${n8n_host}" \
  "N8N_PORT=5678" \
  "N8N_LISTEN_ADDRESS=0.0.0.0" \
  "N8N_PROTOCOL=https" \
  "N8N_EDITOR_BASE_URL=https://${n8n_host}:8443/" \
  "N8N_WEBHOOK_URL=https://${n8n_host}:8443/" \
  "N8N_PROXY_HOPS=1" \
  "N8N_SECURE_COOKIE=true" \
  "N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true" \
  "N8N_BLOCK_ENV_ACCESS_IN_NODE=true" \
  "N8N_BLOCK_FILE_ACCESS_TO_N8N_FILES=true" \
  "N8N_DIAGNOSTICS_ENABLED=false" \
  "N8N_PERSONALIZATION_ENABLED=false" \
  "N8N_HIRING_BANNER_ENABLED=false" \
  "N8N_TEMPLATES_ENABLED=false" \
  "N8N_COMMUNITY_PACKAGES_ENABLED=false" \
  "N8N_UNVERIFIED_PACKAGES_ENABLED=false" \
  "N8N_PUBLIC_API_DISABLED=true" \
  "N8N_METRICS=false" \
  "GENERIC_TIMEZONE=UTC" \
  "TZ=UTC" > "$env_file"

unset encryption_key n8n_host
'
```

Keep the environment file owned by root with mode `0600`. The encryption key must be retained with backups; replacing it prevents n8n from decrypting stored credentials.

## Deploy

```bash
sudo cp \
  /usr/share/pasiv-black-box/quadlets/n8n/n8n.container \
  /etc/containers/systemd/n8n.container
sudo chown root:root /etc/containers/systemd/n8n.container
sudo chmod 0644 /etc/containers/systemd/n8n.container
sudo systemctl daemon-reload
sudo systemctl start n8n.service
```

Do not run `systemctl enable n8n.service`. Quadlet generates the service at runtime, and its `[Install]` section creates the boot dependency automatically.

## Caddy and Authelia

A sanitized Caddy configuration for Tailscale-only HTTPS access with Authelia is:

```caddyfile
n8n.example.com {
    forward_auth authelia:9091 {
        uri /api/verify?rd=https://auth.example.com:8443
        copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }

    reverse_proxy n8n:5678
}
```

Caddy, Authelia, and n8n must join `pasiv-monitoring.network`. Keep the DNS record pointed at the appliance's private overlay-network address so the editor is unreachable from the public Internet.

After opening the authenticated HTTPS site, create the initial n8n owner account. This account remains required even when Authelia protects the outer route.

## Connect n8n to OpenClaw

OpenClaw must:

- join `pasiv-monitoring.network` with alias `openclaw`;
- listen on its container LAN interface without publishing a host port;
- enable its authenticated Chat Completions endpoint;
- keep `OPENCLAW_GATEWAY_TOKEN` secret.

Create an n8n **OpenAI** credential with:

| Field | Value |
| --- | --- |
| API key | The existing `OPENCLAW_GATEWAY_TOKEN` |
| Base URL | `http://openclaw:18789/v1` |
| Organization | Leave empty |

Select `openclaw/default` in the OpenAI Chat Model node and keep **Use Responses API** disabled.

## Validated read-only diagnostic workflow

Use a deterministic data-first design:

```text
When chat message received -> HTTP Request -> AI Agent
                                      |
                                      +-> OpenAI Chat Model -> OpenClaw
```

Configure the regular HTTP Request node—not an AI Tool subnode—with:

| Setting | Value |
| --- | --- |
| Method | `GET` |
| URL | `http://prometheus:9090/-/healthy` |
| Authentication | None |
| Headers, query, body | Disabled |

Set the AI Agent prompt source to **Define below**:

```text
User request:
{{ $('When chat message received').item.json.chatInput }}

Observed Prometheus health response:
{{ JSON.stringify($json) }}

Answer using only the observed response. Clearly state whether Prometheus is healthy. Do not perform or propose any other action.
```

Use this system message:

```text
You are Pasiv, a read-only diagnostic agent for the Pasiv Black Box monitoring node and home network-lab.

Explain alerts and failures, identify likely causes, and propose exact diagnostic checks or fixes.

Strict rules:
- Use only the read-only data provided to you.
- Never change configuration or data.
- Never restart, stop, start, create, or delete services or containers.
- Never perform repairs.
- Clearly separate observed facts from likely causes.
- If a change is required, describe the proposed change and wait for explicit approval.
```

Set **Max Iterations** to `1`. Keep **Make Chat Publicly Available** disabled and do not publish the workflow during initial testing.

Do not attach the HTTP Request node to the AI Agent's Tool connector. In physical validation, the OpenClaw compatibility endpoint handled model responses correctly but did not expose n8n tool calls to the model. Repeated agent attempts consumed unnecessary tokens. Collect fixed read-only evidence first and pass that evidence to the model once.

This structure enforces the current read-only boundary: the workflow has a fixed GET request and no SSH, Execute Command, Podman socket, systemd interface, write-capable HTTP request, or service-control node.

## Python task-runner warning

The standard image can log that Python 3 is missing when it attempts to initialize the internal Python task runner. Python is not needed for this workflow, and the warning does not affect n8n health or the validated HTTP and AI nodes. Do not build a custom image merely to remove this warning.

## Validate

```bash
sudo podman inspect n8n \
  --format 'state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'

sudo podman exec n8n wget -qO- http://127.0.0.1:5678/healthz

sudo podman exec caddy sh -c \
  'wget -qO- http://n8n:5678/healthz'

readlink -f /run/systemd/generator/multi-user.target.wants/n8n.service
```

Expected results are a running, healthy container, `{"status":"ok"}` from both health requests, and a link to `/run/systemd/generator/n8n.service`.

## Physical validation

This design was validated on physical Pasiv Black Box hardware with SELinux enforcing, n8n 2.38.7, private Caddy-to-n8n connectivity, Tailscale-only HTTPS, Authelia redirection, persistent owner/credential/workflow state after an n8n service restart, authenticated OpenClaw model discovery, and one successful read-only Prometheus health workflow. A full host reboot has not yet been validated for this module.
