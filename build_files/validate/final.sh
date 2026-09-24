#!/usr/bin/bash
set -euo pipefail

pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

OS_RELEASE_USR=/usr/lib/os-release
OS_RELEASE_ETC=/etc/os-release
[[ -r "${OS_RELEASE_USR}" ]] || fail "${OS_RELEASE_USR} is missing"

# shellcheck disable=SC1090
source "${OS_RELEASE_USR}"

[[ "${ID:-}" == "pasiv-black-box" ]] || fail "ID=${ID:-unset}; expected pasiv-black-box"
[[ "${NAME:-}" == "Pasiv Black Box" ]] || fail "NAME=${NAME:-unset}; expected Pasiv Black Box"
[[ "${PRETTY_NAME:-}" == "Pasiv Black Box 10" ]] || fail "PRETTY_NAME=${PRETTY_NAME:-unset}; expected Pasiv Black Box 10"
[[ "${VERSION_ID%%.*}" == "10" ]] || fail "VERSION_ID=${VERSION_ID:-unset}; expected EL10 major version"
[[ "${PLATFORM_ID:-}" == "platform:el10" ]] || fail "PLATFORM_ID=${PLATFORM_ID:-unset}; expected platform:el10"

for family in almalinux rhel centos fedora; do
    [[ " ${ID_LIKE:-} " == *" ${family} "* ]] || fail "ID_LIKE=${ID_LIKE:-unset}; missing ${family}"
done

[[ "${VARIANT:-}" == "Pasiv Black Box" ]] || fail "VARIANT=${VARIANT:-unset}"
[[ "${VARIANT_ID:-}" == "pasiv-black-box" ]] || fail "VARIANT_ID=${VARIANT_ID:-unset}"
[[ "${IMAGE_ID:-}" == "pasiv-black-box" ]] || fail "IMAGE_ID=${IMAGE_ID:-unset}"
[[ "${IMAGE_VERSION:-}" == "10" ]] || fail "IMAGE_VERSION=${IMAGE_VERSION:-unset}"
[[ "${VENDOR_NAME:-}" == "Highway to IT" ]] || fail "VENDOR_NAME=${VENDOR_NAME:-unset}"
[[ "${VENDOR_URL:-}" == "https://github.com/highwaytoit" ]] || fail "VENDOR_URL=${VENDOR_URL:-unset}"
[[ "${HOME_URL:-}" == "https://github.com/highwaytoit/pasiv-black-box" ]] || fail "HOME_URL=${HOME_URL:-unset}"
[[ "${DOCUMENTATION_URL:-}" == "https://github.com/highwaytoit/pasiv-black-box/tree/main/docs" ]] || fail "DOCUMENTATION_URL=${DOCUMENTATION_URL:-unset}"
[[ "${SUPPORT_URL:-}" == "https://github.com/highwaytoit/pasiv-black-box/issues" ]] || fail "SUPPORT_URL=${SUPPORT_URL:-unset}"
[[ "${BUG_REPORT_URL:-}" == "https://github.com/highwaytoit/pasiv-black-box/issues" ]] || fail "BUG_REPORT_URL=${BUG_REPORT_URL:-unset}"
[[ "${CPE_NAME:-}" == "cpe:/o:highwaytoit:pasiv-black-box:10" ]] || fail "CPE_NAME=${CPE_NAME:-unset}"

[[ "${PASIV_BLACK_BOX_BASE_ID:-}" == "home-server-base" ]] || fail "base ID metadata is not home-server-base"
[[ "${PASIV_BLACK_BOX_BASE_PRETTY_NAME:-}" == "Home Server Base 10" ]] || fail "base PRETTY_NAME metadata is not Home Server Base 10"
[[ "${PASIV_BLACK_BOX_BASE_VERSION_ID%%.*}" == "10" ]] || fail "base VERSION_ID metadata is not Home Server Base 10"
[[ "${PASIV_BLACK_BOX_BASE_PLATFORM_ID:-}" == "platform:el10" ]] || fail "base PLATFORM_ID metadata is not platform:el10"
[[ "${PASIV_BLACK_BOX_BASE_CPE_NAME:-}" == "cpe:/o:home-server-project:home-server-base:10" ]] || fail "base CPE metadata does not identify Home Server Base 10"
[[ "${PASIV_BLACK_BOX_BASE_PROFILE:-}" == "almalinux-10-minimal-plus" ]] || fail "base profile metadata is incorrect"
[[ "${PASIV_BLACK_BOX_BASE_CHANNEL:-}" == "stable" ]] || fail "base channel metadata is not stable"

[[ "${HOME_SERVER_BASE_UPSTREAM_ID:-}" == "almalinux" ]] || fail "Home Server Base upstream ID metadata is not almalinux"
[[ "${HOME_SERVER_BASE_UPSTREAM_VERSION_ID%%.*}" == "10" ]] || fail "Home Server Base upstream VERSION_ID metadata is not AlmaLinux 10"
[[ "${HOME_SERVER_BASE_UPSTREAM_PLATFORM_ID:-}" == "platform:el10" ]] || fail "Home Server Base upstream PLATFORM_ID metadata is not platform:el10"
[[ "${HOME_SERVER_BASE_UPSTREAM_CPE_NAME:-}" == cpe:/o:almalinux:* ]] || fail "Home Server Base upstream CPE metadata does not identify AlmaLinux"

for key in ALMALINUX_MANTISBT_PROJECT ALMALINUX_MANTISBT_PROJECT_VERSION REDHAT_SUPPORT_PRODUCT REDHAT_SUPPORT_PRODUCT_VERSION SUPPORT_END LOGO; do
    if grep -q "^${key}=" "${OS_RELEASE_USR}"; then
        fail "upstream product field ${key} remains in Pasiv os-release"
    fi
done

if [[ -e "${OS_RELEASE_ETC}" ]] && ! [[ "${OS_RELEASE_ETC}" -ef "${OS_RELEASE_USR}" ]]; then
    for key in ID NAME PRETTY_NAME VARIANT VARIANT_ID IMAGE_ID IMAGE_VERSION VENDOR_NAME CPE_NAME PASIV_BLACK_BOX_BASE_ID PASIV_BLACK_BOX_BASE_CHANNEL HOME_SERVER_BASE_UPSTREAM_ID; do
        usr_value="$(grep -E "^${key}=" "${OS_RELEASE_USR}" | head -n1 || true)"
        etc_value="$(grep -E "^${key}=" "${OS_RELEASE_ETC}" | head -n1 || true)"
        [[ "${usr_value}" == "${etc_value}" ]] || fail "${key} differs between /usr/lib/os-release and /etc/os-release"
    done
fi

for legacy_path in \
    /usr/libexec/alma-black-box \
    /usr/share/alma-black-box \
    /etc/profile.d/zz-alma-black-box-prompt.sh \
    /etc/sudoers.d/90-alma-black-box-passwordless-wheel \
    /usr/lib/tmpfiles.d/alma-black-box-resolved.conf \
    /usr/lib/systemd/system/alma-black-box-update.service \
    /usr/lib/systemd/system/alma-black-box-update.timer; do
    [[ ! -e "${legacy_path}" ]] || fail "legacy Alma Black Box path remains: ${legacy_path}"
done

# Passive-owned package delta: exactly the 36 packages requested by this image.
rpm -q \
    NetworkManager-wifi \
    nut \
    nut-client \
    libusb1-devel \
    pcp \
    pcp-pmda-openmetrics \
    pcp-system-tools \
    net-snmp-utils \
    wireguard-tools \
    fwupd-efi \
    amd-ucode-firmware \
    amd-gpu-firmware \
    intel-gpu-firmware \
    iwlegacy-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    atheros-firmware \
    realtek-firmware \
    smartmontools \
    lm_sensors \
    nvme-cli \
    usbutils \
    ethtool \
    powertop \
    vim-enhanced \
    tmux \
    git \
    zstd \
    gcc \
    gcc-c++ \
    make \
    unzip \
    cockpit-system \
    cockpit-files \
    cockpit-podman \
    cockpit-storaged \
    cockpit-upside >/dev/null

# UPSide is consumed from the Home Server Packages stable channel.
test -f /usr/share/cockpit/upside/manifest.json

for cmd in \
    upsc nut-scanner pmlogger pminfo pmrep \
    smartctl sensors nvme lsusb ethtool powertop \
    vim tmux snmpget snmpwalk unzip \
    git zstd gcc g++ make cockpit-bridge; do
    command -v "${cmd}" >/dev/null
done

# uBlue Brew payload and service policy.
test -f /usr/share/homebrew.tar.zst
test -f /usr/lib/systemd/system/brew-setup.service
test -f /usr/lib/systemd/system/brew-update.service
test -f /usr/lib/systemd/system/brew-update.timer
test -f /usr/lib/systemd/system/brew-upgrade.service
test -f /usr/lib/systemd/system/brew-upgrade.timer
test -f /etc/profile.d/brew.sh
tar --zstd -tf /usr/share/homebrew.tar.zst | grep -Eq '(^|/)home/linuxbrew/.linuxbrew/bin/brew$'
test "$(systemctl is-enabled brew-setup.service)" = "enabled"
test "$(systemctl is-enabled brew-update.timer)" = "enabled"
test "$(systemctl is-enabled brew-upgrade.timer 2>/dev/null || true)" = "disabled"

# PCP / UPSide history support.
test -e /usr/lib64/libusb-1.0.so
test -x /usr/libexec/pcp/bin/pmcd
test -x /usr/libexec/pcp/pmdas/openmetrics/Install
test -f /usr/lib/tmpfiles.d/pcp-pmda-openmetrics.conf
test "$(systemctl is-enabled pmcd.service)" = "enabled"
test "$(systemctl is-enabled pmlogger.service)" = "enabled"

# Inherited zram and resolved integration required by Passive.
test -f /etc/systemd/zram-generator.conf
grep -Fqx '[zram0]' /etc/systemd/zram-generator.conf
test -f /etc/NetworkManager/conf.d/90-systemd-resolved.conf
grep -Fqx '[main]' /etc/NetworkManager/conf.d/90-systemd-resolved.conf
grep -Fqx 'dns=systemd-resolved' /etc/NetworkManager/conf.d/90-systemd-resolved.conf
test -f /usr/lib/tmpfiles.d/pasiv-black-box-resolved.conf
grep -Fqx 'L+ /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf' \
    /usr/lib/tmpfiles.d/pasiv-black-box-resolved.conf

# Administrative and update policy.
test -f /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel
grep -Fqx '%wheel ALL=(ALL) NOPASSWD: ALL' \
    /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel
test "$(stat -c '%a %U %G' /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel)" = "440 root root"
visudo -cf /etc/sudoers >/dev/null
test -f /etc/profile.d/zz-pasiv-black-box-prompt.sh
test -f /usr/lib/systemd/system/pasiv-black-box-update.service
test -f /usr/lib/systemd/system/pasiv-black-box-update.timer
test "$(systemctl is-enabled bootc-fetch-apply-updates.timer)" = "masked"
test "$(systemctl is-enabled bootc-fetch-apply-updates.service)" = "masked"
test "$(systemctl is-enabled pasiv-black-box-update.timer)" = "enabled"

# NUT final state.
getent passwd nut >/dev/null
getent group nut >/dev/null
for group_name in tty dialout; do
    id -nG nut | tr ' ' '\n' | grep -Fxq "${group_name}"
done
test "$(stat -c '%a %U %G' /etc/ups/upsd.conf)" = "640 root nut"
test "$(stat -c '%a %U %G' /etc/ups/upsd.users)" = "640 root nut"
test -f /usr/lib/systemd/system/nut-server.service.d/10-network-online.conf
grep -Fqx 'Wants=network-online.target' /usr/lib/systemd/system/nut-server.service.d/10-network-online.conf
grep -Fqx 'After=network-online.target' /usr/lib/systemd/system/nut-server.service.d/10-network-online.conf
for unit in nut-server.service nut-monitor.service nut-driver@.service; do
    [[ "$(systemctl is-enabled "${unit}" 2>/dev/null || true)" != "enabled" ]]
done

# Completed SELinux policy must remain readable.
semodule -l >/dev/null

# Preserve the existing inactive Quadlet library and documentation contract.
for template in \
    cockpit/cockpit.container \
    network/pasiv-monitoring.network \
    caddy/caddy.container \
    authelia/authelia.container \
    uptime-kuma/uptime-kuma.container \
    openclaw/openclaw.container \
    n8n/n8n.container \
    grafana/grafana.container \
    prometheus/prometheus.container \
    blackbox-exporter/blackbox-exporter.container \
    snmp-exporter/snmp-exporter.container \
    node-exporter/node-exporter.container \
    nut-exporter/nut-exporter.container \
    loki/loki.container \
    alloy/alloy.container \
    victoriametrics/victoriametrics.container \
    alertmanager/alertmanager.container; do
    test -f "/usr/share/pasiv-black-box/quadlets/${template}"
done

test -f /usr/share/pasiv-black-box/quadlets/prometheus/examples/prometheus.yml
test -f /usr/share/pasiv-black-box/quadlets/blackbox-exporter/examples/blackbox.yml
test -f /usr/share/pasiv-black-box/quadlets/blackbox-exporter/docs/BLACKBOX-EXPORTER.md
test -f /usr/share/pasiv-black-box/quadlets/snmp-exporter/examples/snmp-auth.yml
test -f /usr/share/pasiv-black-box/quadlets/snmp-exporter/examples/snmp.env.example
test -f /usr/share/pasiv-black-box/quadlets/snmp-exporter/docs/SNMP-EXPORTER.md
test -f /usr/share/pasiv-black-box/quadlets/node-exporter/examples/prometheus-job.yml
test -f /usr/share/pasiv-black-box/quadlets/node-exporter/docs/NODE-EXPORTER.md
test -f /usr/share/pasiv-black-box/quadlets/nut-exporter/examples/prometheus-job.yml
test -f /usr/share/pasiv-black-box/quadlets/nut-exporter/docs/NUT-EXPORTER.md
test -f /usr/share/pasiv-black-box/quadlets/uptime-kuma/docs/UPTIME-KUMA.md
test -f /usr/share/pasiv-black-box/quadlets/openclaw/docs/OPENCLAW.md
test -f /usr/share/pasiv-black-box/quadlets/openclaw/examples/openclaw.json.example
test -f /usr/share/pasiv-black-box/quadlets/openclaw/examples/openclaw.env.example
test -f /usr/share/pasiv-black-box/quadlets/n8n/docs/N8N.md
test -f /usr/share/pasiv-black-box/quadlets/n8n/examples/n8n.env.example
test -f /usr/share/pasiv-black-box/quadlets/alertmanager/examples/alertmanager.yml
test -f /usr/share/pasiv-black-box/doc/README.md
test -f /usr/share/pasiv-black-box/doc/QUADLETS.md
test -f /usr/share/pasiv-black-box/doc/QUADLET-LIBRARY.md
test -f /usr/share/pasiv-black-box/doc/NUT-UPSide.md
test -x /usr/libexec/pasiv-black-box/health/final
! grep -q '@@COCKPIT_WS_IMAGE@@' /usr/share/pasiv-black-box/quadlets/cockpit/cockpit.container
grep -Fq '@@NODE_EXPORTER_LISTEN_ADDRESS@@' /usr/share/pasiv-black-box/quadlets/node-exporter/node-exporter.container
grep -Fq '@@NUT_EXPORTER_LISTEN_ADDRESS@@' /usr/share/pasiv-black-box/quadlets/nut-exporter/nut-exporter.container
grep -Fq '@@NUT_EXPORTER_LISTEN_ADDRESS@@' /usr/share/pasiv-black-box/quadlets/nut-exporter/examples/prometheus-job.yml
grep -Fq '@@NUT_UPS_NAME@@' /usr/share/pasiv-black-box/quadlets/nut-exporter/examples/prometheus-job.yml

# Final image trust.
POLICY=/etc/containers/policy.json
REGISTRY_CONFIG=/etc/containers/registries.d/ghcr.io-highwaytoit.yaml
IMAGE_REPOSITORY=ghcr.io/highwaytoit/pasiv-black-box
jq empty "${POLICY}"
test -f /usr/lib/pki/containers/highwaytoit.pub
test -f "${REGISTRY_CONFIG}"
grep -Fq "${IMAGE_REPOSITORY}:" "${REGISTRY_CONFIG}"
grep -Fq "use-sigstore-attachments: true" "${REGISTRY_CONFIG}"

test "$(stat -c '%a %U %G' /var/tmp)" = "1777 root root"

pass "Pasiv Black Box completed-image health"
printf 'PASIV HEALTH: PASS\n'
