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

pass "Pasiv Black Box identity, Home Server Base 10 parent, and AlmaLinux 10 upstream metadata"
printf 'PASIV IDENTITY: PASS\n'
