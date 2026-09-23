#!/usr/bin/bash
set -ouex pipefail

: "${IMAGE_REPOSITORY:?IMAGE_REPOSITORY must be set by the image build}"
source /ctx/build_files/software.env
: "${PASIV_BLACK_BOX_PACKAGES:?PASIV_BLACK_BOX_PACKAGES must be set}"
: "${COCKPIT_WS_IMAGE:?COCKPIT_WS_IMAGE must be set}"

# Declarative host configuration first.
cp -avf /ctx/system_files/. /

# Follow the Fedora CoreOS/uCore appliance-style administration model: trusted
# administrators in wheel can use sudo without repeated password prompts.
chown root:root /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel
chmod 0440 /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel

# AlmaLinux 10.1+ enables CRB by default. EPEL software on EL10 expects the
# CRB SELinux policy split to be available, so fail clearly if the upstream
# base ever changes that contract rather than silently composing a broken image.
if ! dnf repolist --enabled | grep -Eiq '(^|[[:space:]])crb([[:space:]]|$)'; then
    echo "ERROR: AlmaLinux CRB repository is not enabled in the upstream bootc image."
    exit 1
fi

# EPEL provides host packages used by this image, including NUT.
dnf install -y epel-release

read -r -a native_packages <<< "${PASIV_BLACK_BOX_PACKAGES}"
dnf install -y "${native_packages[@]}"

# EL10 bootc keeps vendor groups in /usr/lib/group while systemd-sysusers writes
# supplementary memberships to /etc/gshadow.  NUT's runtime directories are
# root:dialout 0770, so the nut service account must carry the package-declared
# tty and dialout memberships in the image-managed group database itself.
for group_name in tty dialout; do
    grep -q "^${group_name}:" /usr/lib/group
 done
awk -F: -v OFS=: '
$1 == "tty" || $1 == "dialout" {
    count = split($4, members, ",")
    found = 0
    for (i = 1; i <= count; i++) {
        if (members[i] == "nut")
            found = 1
    }
    if (!found)
        $4 = ($4 == "" ? "nut" : $4 ",nut")
}
{ print }
' /usr/lib/group > /tmp/pasiv-group
install -o root -g root -m0644 /tmp/pasiv-group /usr/lib/group
rm -f /tmp/pasiv-group

# NUT ships these files as root:nut 0640. Preserve those permissions in the
# vendor /etc payload so upsd can read them after a fresh bootc deployment.
for nut_file in /etc/ups/upsd.conf /etc/ups/upsd.users; do
    test -f "${nut_file}"
    chown root:nut "${nut_file}"
    chmod 0640 "${nut_file}"
done

# PCP provides UPSide's optional historical trends. Keep the focused PCP +
# OpenMetrics set rather than the broader pcp-zeroconf bundle, and explicitly
# enable the two services UPSide needs for history collection.
systemctl enable pmcd.service pmlogger.service

# UPSide is built, tested, and published by Home Server Packages. CI resolves
# the stable artifact to an exact digest before this image build starts.
dnf install -y /upside-rpm/cockpit-upside-*.noarch.rpm

# uBlue Brew supplies the official Homebrew bootstrap payload and bootc
# integration. Keep Homebrew metadata current automatically, while leaving
# installed formula upgrades under administrator control.
systemctl preset brew-setup.service brew-update.timer
systemctl disable brew-upgrade.timer 2>/dev/null || true

# NUT configuration is hardware/site specific and is never enabled by the image.
for unit in nut-server.service nut-monitor.service nut-driver@.service; do
    systemctl disable "${unit}" 2>/dev/null || true
done

# The web-facing Cockpit service is intentionally a Quadlet. Keep native ws
# socket/service disabled if a future dependency ever happens to pull it in.
systemctl disable cockpit.socket cockpit.service 2>/dev/null || true

# Upstream bootc auto-update units reboot after applying an update. Pasiv Black
# Box stages updates automatically but leaves reboot timing to the administrator.
systemctl mask bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service
systemctl enable pasiv-black-box-update.timer

# Install image signature trust for future bootc updates from this repository.
/ctx/build_files/install-image-trust.sh "${IMAGE_REPOSITORY}"

# Ship local operator documentation and inactive Quadlet templates.
install -d -m0755 /usr/share/pasiv-black-box/doc
cp -avf /ctx/docs/. /usr/share/pasiv-black-box/doc/

install -d -m0755 /usr/share/pasiv-black-box/quadlets
cp -avf /ctx/quadlets/. /usr/share/pasiv-black-box/quadlets/
sed -i "s|@@COCKPIT_WS_IMAGE@@|${COCKPIT_WS_IMAGE}|g" \
    /usr/share/pasiv-black-box/quadlets/cockpit/cockpit.container

install -d -m0755 /usr/libexec/pasiv-black-box/health
install -m0755 /ctx/build_files/validate/identity.sh \
    /usr/libexec/pasiv-black-box/health/identity

# Build-time validation. If a declared host capability disappears, fail the image.
for cmd in \
    bootc podman nmcli nmtui firewall-cmd sshd sudo visudo \
    upsc nut-scanner pmlogger pminfo pmrep \
    fwupdmgr smartctl sensors nvme lsusb lspci ethtool powertop \
    nano vim tmux jq rsync tcpdump dig traceroute nc iperf3 \
    snmpget snmpwalk \
    openssl curl lsof file unzip semanage \
    git zstd gcc g++ make ps \
    cockpit-bridge resolvectl; do
    command -v "${cmd}"
done

rpm -q \
    NetworkManager-tui \
    NetworkManager-wifi \
    systemd-resolved \
    sudo \
    fwupd \
    fwupd-efi \
    amd-ucode-firmware \
    amd-gpu-firmware \
    microcode_ctl \
    intel-gpu-firmware \
    iwlegacy-firmware \
    iwlwifi-dvm-firmware \
    iwlwifi-mvm-firmware \
    atheros-firmware \
    realtek-firmware \
    qemu-guest-agent \
    zram-generator \
    libusb1-devel \
    pcp \
    pcp-pmda-openmetrics \
    pcp-system-tools \
    net-snmp-utils \
    selinux-policy-extra \
    cockpit-system \
    cockpit-files \
    cockpit-podman \
    cockpit-storaged \
    cockpit-upside \
    git \
    zstd \
    gcc \
    gcc-c++ \
    make \
    procps-ng

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

test -e /usr/lib64/libusb-1.0.so

test -x /usr/libexec/pcp/bin/pmcd
test -x /usr/libexec/pcp/pmdas/openmetrics/Install
test -f /usr/lib/tmpfiles.d/pcp-pmda-openmetrics.conf
test "$(systemctl is-enabled pmcd.service)" = "enabled"
test "$(systemctl is-enabled pmlogger.service)" = "enabled"

test -f /etc/systemd/zram-generator.conf
grep -Fqx '[zram0]' /etc/systemd/zram-generator.conf

test -f /etc/NetworkManager/conf.d/90-systemd-resolved.conf
grep -Fqx '[main]' /etc/NetworkManager/conf.d/90-systemd-resolved.conf
grep -Fqx 'dns=systemd-resolved' /etc/NetworkManager/conf.d/90-systemd-resolved.conf

test -f /usr/lib/tmpfiles.d/pasiv-black-box-resolved.conf
grep -Fqx 'L+ /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf' \
    /usr/lib/tmpfiles.d/pasiv-black-box-resolved.conf

test -f /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel
grep -Fqx '%wheel ALL=(ALL) NOPASSWD: ALL' \
    /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel
test "$(stat -c '%a %U %G' /etc/sudoers.d/90-pasiv-black-box-passwordless-wheel)" = "440 root root"
visudo -cf /etc/sudoers

test -f /etc/profile.d/zz-pasiv-black-box-prompt.sh

test -f /usr/lib/systemd/system/pasiv-black-box-update.service
test -f /usr/lib/systemd/system/pasiv-black-box-update.timer
test "$(systemctl is-enabled bootc-fetch-apply-updates.timer)" = "masked"
test "$(systemctl is-enabled bootc-fetch-apply-updates.service)" = "masked"
test "$(systemctl is-enabled pasiv-black-box-update.timer)" = "enabled"

# nut-client can be unpacked before the main nut package creates its account,
# which produces RPM ownership warnings during the transaction. Require the
# completed image to contain the intended NUT user/group state and secure files.
getent passwd nut >/dev/null
getent group nut >/dev/null
for group_name in tty dialout; do
    id -nG nut | tr ' ' '\n' | grep -Fxq "${group_name}"
done
test "$(stat -c '%a %U %G' /etc/ups/upsd.conf)" = "640 root nut"
test "$(stat -c '%a %U %G' /etc/ups/upsd.users)" = "640 root nut"
test -f /usr/lib/systemd/system/nut-server.service.d/10-network-online.conf
grep -Fqx 'Wants=network-online.target' \
    /usr/lib/systemd/system/nut-server.service.d/10-network-online.conf
grep -Fqx 'After=network-online.target' \
    /usr/lib/systemd/system/nut-server.service.d/10-network-online.conf

# EL10 SELinux policy RPM scriptlets may emit transaction warnings during bootc
# composition. Require the completed policy store to remain readable.
semodule -l >/dev/null

# The complete inactive Quadlet library must be present in the composed image.
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
test -f /usr/share/cockpit/upside/manifest.json
test -x /usr/libexec/pasiv-black-box/health/identity
! grep -q '@@COCKPIT_WS_IMAGE@@' /usr/share/pasiv-black-box/quadlets/cockpit/cockpit.container
grep -Fq '@@NODE_EXPORTER_LISTEN_ADDRESS@@' /usr/share/pasiv-black-box/quadlets/node-exporter/node-exporter.container
grep -Fq '@@NUT_EXPORTER_LISTEN_ADDRESS@@' /usr/share/pasiv-black-box/quadlets/nut-exporter/nut-exporter.container
grep -Fq '@@NUT_EXPORTER_LISTEN_ADDRESS@@' /usr/share/pasiv-black-box/quadlets/nut-exporter/examples/prometheus-job.yml
grep -Fq '@@NUT_UPS_NAME@@' /usr/share/pasiv-black-box/quadlets/nut-exporter/examples/prometheus-job.yml

# EPEL is a Pasiv build-time input. Keep its repo definitions for provenance,
# but disable them in the deployed image.
for repo_file in /etc/yum.repos.d/epel*.repo; do
    [[ -e "${repo_file}" ]] || continue
    sed -Ei 's/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*1[[:space:]]*$/enabled=0/' "${repo_file}"
done

# Fail the build if any known external source remains enabled.
if dnf repolist --enabled | grep -Eiq 'epel|tailscale|netbird'; then
    echo "ERROR: an external package repository remains enabled in the final image."
    dnf repolist --enabled
    exit 1
fi

# Services which define the host itself remain available. Tailscale and NetBird
# are inherited enabled from Home Server Base 10. UPS behavior, Cockpit web
# service, and monitoring applications remain appliance-specific. PCP is
# host-native telemetry support for UPSide history, so its collection services
# are enabled by the image.
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable systemd-resolved.service
systemctl enable firewalld.service 2>/dev/null || true
systemctl enable sshd.service 2>/dev/null || true
systemctl enable pmcd.service pmlogger.service

test "$(systemctl is-enabled systemd-resolved.service)" = "enabled"
test "$(systemctl is-enabled pmcd.service)" = "enabled"
test "$(systemctl is-enabled pmlogger.service)" = "enabled"

# bootc images must not carry build-time package-manager/runtime state in /var.
# Alma's own atomic image derivatives clean /var after composition. Keep the
# standard /var/tmp mountpoint in the image skeleton because early services such
# as systemd-resolved can require PrivateTmp before systemd-tmpfiles-setup runs.
dnf clean all
rm -rf /var
install -d -m0755 /var
install -d -m1777 /var/tmp
test "$(stat -c '%a %U %G' /var/tmp)" = "1777 root root"
