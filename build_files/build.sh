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

# Home Server Base 10 already provides the EPEL capability. Passive consumes
# EPEL packages during composition without reinstalling epel-release.

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

# UPSide is built, tested, and published by Home Server Packages. Consume the
# Home Server Packages stable channel directly.
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

# bootc images must not carry build-time package-manager/runtime state in /var.
# Alma's own atomic image derivatives clean /var after composition. Keep the
# standard /var/tmp mountpoint in the image skeleton because early services such
# as systemd-resolved can require PrivateTmp before systemd-tmpfiles-setup runs.
dnf clean all
rm -rf /var
install -d -m0755 /var
install -d -m1777 /var/tmp
