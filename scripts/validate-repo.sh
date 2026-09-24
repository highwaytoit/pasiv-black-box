#!/usr/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

bash -n build_files/build.sh
bash -n build_files/finalize-image.sh
bash -n build_files/install-image-trust.sh
bash -n build_files/software.env
bash -n build_files/validate/final.sh

python3 - <<'PY2'
from pathlib import Path
import yaml

for workflow in (
    '.github/workflows/build.yml',
    '.github/workflows/build-testing.yml',
):
    with Path(workflow).open() as f:
        yaml.safe_load(f)

required = [
    'Containerfile',
    'README.md',
    'cosign.pub',
    'almalinux-bootc.pub',
    'docs/README.md',
    'docs/QUADLETS.md',
    'docs/QUADLET-LIBRARY.md',
    'docs/NUT-UPSide.md',
    'quadlets/cockpit/cockpit.container',
    'quadlets/cockpit/docs/COCKPIT.md',
    'quadlets/network/pasiv-monitoring.network',
    'quadlets/network/docs/NETWORK.md',
    'quadlets/caddy/caddy.container',
    'quadlets/caddy/docs/CADDY.md',
    'quadlets/authelia/authelia.container',
    'quadlets/authelia/docs/AUTHELIA.md',
    'quadlets/n8n/n8n.container',
    'quadlets/n8n/docs/N8N.md',
    'quadlets/n8n/examples/n8n.env.example',
    'quadlets/grafana/grafana.container',
    'quadlets/grafana/docs/GRAFANA.md',
    'quadlets/prometheus/prometheus.container',
    'quadlets/prometheus/examples/prometheus.yml',
    'quadlets/prometheus/docs/PROMETHEUS.md',
    'quadlets/blackbox-exporter/blackbox-exporter.container',
    'quadlets/blackbox-exporter/examples/blackbox.yml',
    'quadlets/blackbox-exporter/docs/BLACKBOX-EXPORTER.md',
    'quadlets/snmp-exporter/snmp-exporter.container',
    'quadlets/snmp-exporter/examples/snmp-auth.yml',
    'quadlets/snmp-exporter/examples/snmp.env.example',
    'quadlets/snmp-exporter/docs/SNMP-EXPORTER.md',
    'quadlets/node-exporter/node-exporter.container',
    'quadlets/node-exporter/examples/prometheus-job.yml',
    'quadlets/node-exporter/docs/NODE-EXPORTER.md',
    'quadlets/loki/loki.container',
    'quadlets/loki/docs/LOKI.md',
    'quadlets/alloy/alloy.container',
    'quadlets/alloy/docs/ALLOY.md',
    'quadlets/victoriametrics/victoriametrics.container',
    'quadlets/victoriametrics/docs/VICTORIAMETRICS.md',
    'quadlets/alertmanager/alertmanager.container',
    'quadlets/alertmanager/examples/alertmanager.yml',
    'quadlets/alertmanager/docs/ALERTMANAGER.md',
    'build_files/finalize-image.sh',
    'build_files/validate/final.sh',
    'system_files/etc/NetworkManager/conf.d/90-systemd-resolved.conf',
    'system_files/usr/lib/tmpfiles.d/pasiv-black-box-resolved.conf',
    'system_files/etc/sudoers.d/90-pasiv-black-box-passwordless-wheel',
    'system_files/etc/profile.d/zz-pasiv-black-box-prompt.sh',
    'system_files/usr/lib/systemd/system/pasiv-black-box-update.service',
    'system_files/usr/lib/systemd/system/pasiv-black-box-update.timer',
    'system_files/usr/lib/udev/rules.d/50-usb-realtek-net.rules',
]
for path in required:
    if not Path(path).is_file():
        raise SystemExit(f'missing required file: {path}')

PY2

if [[ -e system_files/etc/hostname ]]; then
    echo 'ERROR: generic Pasiv Black Box image must not bake /etc/hostname; the installer owns the hostname' >&2
    exit 1
fi

grep -Fq '@@NODE_EXPORTER_LISTEN_ADDRESS@@' quadlets/node-exporter/node-exporter.container
grep -Fq '@@NODE_EXPORTER_LISTEN_ADDRESS@@' quadlets/node-exporter/examples/prometheus-job.yml
grep -q 'BEGIN PUBLIC KEY' cosign.pub
grep -q 'BEGIN PUBLIC KEY' almalinux-bootc.pub
grep -Fqx 'dns=systemd-resolved' system_files/etc/NetworkManager/conf.d/90-systemd-resolved.conf
grep -Fqx 'L+ /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf' \
    system_files/usr/lib/tmpfiles.d/pasiv-black-box-resolved.conf
grep -Fqx '%wheel ALL=(ALL) NOPASSWD: ALL' \
    system_files/etc/sudoers.d/90-pasiv-black-box-passwordless-wheel
grep -Fq 'ghcr.io/${{ github.repository_owner }}/pasiv-black-box' .github/workflows/build.yml
grep -Fq 'ghcr.io/${{ github.repository_owner }}/pasiv-black-box' .github/workflows/build-testing.yml
grep -Fq 'ARG IMAGE_REPOSITORY=ghcr.io/highwaytoit/pasiv-black-box' Containerfile
grep -Fq 'PASIV_BLACK_BOX_PACKAGES=' build_files/software.env
grep -Fq 'net-snmp-utils' build_files/software.env

# Site-specific deployment values do not belong in the reusable public library.
if grep -RIn 'highwaytoit\\.com' docs quadlets; then
    echo 'ERROR: site-specific domain remains in docs or Quadlet library' >&2
    exit 1
fi

# Known real deployment addresses must never be copied into the public library.
if grep -RInE '192\.168\.0\.(1|51)|100\.120\.140\.40|10\.89\.1\.1' docs quadlets; then
    echo 'ERROR: site-specific address remains in docs or Quadlet library' >&2
    exit 1
fi

grep -Fqx "PS1='[\\[\\e[31m\\]\\u@\\h\\[\\e[0m\\] \\W]\\$ '" \
    system_files/etc/profile.d/zz-pasiv-black-box-prompt.sh

echo "Static repository validation passed."
