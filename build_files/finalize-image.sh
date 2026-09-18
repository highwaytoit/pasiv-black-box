#!/usr/bin/bash
set -ouex pipefail

: "${IMAGE_REPOSITORY:?IMAGE_REPOSITORY must be set}"

OS_RELEASE_USR=/usr/lib/os-release
OS_RELEASE_ETC=/etc/os-release

[[ -r "${OS_RELEASE_USR}" ]] || {
    echo "ERROR: ${OS_RELEASE_USR} is missing." >&2
    exit 1
}

# Capture the direct Home Server Base parent before applying Pasiv Black Box
# product identity. Home Server Base retains AlmaLinux provenance in namespaced metadata.
# shellcheck disable=SC1090
source "${OS_RELEASE_USR}"
BASE_ID="${ID:-}"
BASE_PRETTY_NAME="${PRETTY_NAME:-}"
BASE_VERSION_ID="${VERSION_ID:-}"
BASE_PLATFORM_ID="${PLATFORM_ID:-}"
BASE_CPE_NAME="${CPE_NAME:-}"
BASE_PROFILE="${HOME_SERVER_BASE_PROFILE:-}"
BASE_CHANNEL="${HOME_SERVER_BASE_CHANNEL:-}"
UPSTREAM_ID="${HOME_SERVER_BASE_UPSTREAM_ID:-}"
UPSTREAM_PRETTY_NAME="${HOME_SERVER_BASE_UPSTREAM_PRETTY_NAME:-}"
UPSTREAM_VERSION_ID="${HOME_SERVER_BASE_UPSTREAM_VERSION_ID:-}"
UPSTREAM_PLATFORM_ID="${HOME_SERVER_BASE_UPSTREAM_PLATFORM_ID:-}"
UPSTREAM_CPE_NAME="${HOME_SERVER_BASE_UPSTREAM_CPE_NAME:-}"

[[ "${BASE_ID}" == "home-server-base" ]] || {
    echo "ERROR: expected Home Server Base parent ID before Pasiv branding, got '${BASE_ID}'." >&2
    exit 1
}
[[ "${BASE_PRETTY_NAME}" == "Home Server Base 10" ]] || {
    echo "ERROR: expected Home Server Base 10 parent, got '${BASE_PRETTY_NAME}'." >&2
    exit 1
}
[[ "${BASE_VERSION_ID%%.*}" == "10" ]] || {
    echo "ERROR: expected Home Server Base major version 10, got '${BASE_VERSION_ID}'." >&2
    exit 1
}
[[ "${BASE_PLATFORM_ID}" == "platform:el10" ]] || {
    echo "ERROR: expected platform:el10, got '${BASE_PLATFORM_ID}'." >&2
    exit 1
}
[[ "${BASE_CPE_NAME}" == "cpe:/o:home-server-project:home-server-base:10" ]] || {
    echo "ERROR: unexpected Home Server Base CPE '${BASE_CPE_NAME}'." >&2
    exit 1
}
[[ "${BASE_PROFILE}" == "almalinux-10-minimal-plus" ]] || {
    echo "ERROR: unexpected Home Server Base profile '${BASE_PROFILE}'." >&2
    exit 1
}
[[ "${BASE_CHANNEL}" == "stable" ]] || {
    echo "ERROR: Pasiv must consume Home Server Base stable, got '${BASE_CHANNEL}'." >&2
    exit 1
}
[[ "${UPSTREAM_ID}" == "almalinux" ]] || {
    echo "ERROR: Home Server Base upstream ID is not AlmaLinux." >&2
    exit 1
}
[[ "${UPSTREAM_VERSION_ID%%.*}" == "10" ]] || {
    echo "ERROR: Home Server Base upstream VERSION_ID is not AlmaLinux 10." >&2
    exit 1
}
[[ "${UPSTREAM_PLATFORM_ID}" == "platform:el10" ]] || {
    echo "ERROR: Home Server Base upstream PLATFORM_ID is not platform:el10." >&2
    exit 1
}
[[ "${UPSTREAM_CPE_NAME}" == cpe:/o:almalinux:* ]] || {
    echo "ERROR: Home Server Base upstream CPE does not identify AlmaLinux." >&2
    exit 1
}

OS_RELEASE_FILES=("${OS_RELEASE_USR}")
if [[ -e "${OS_RELEASE_ETC}" ]] && ! [[ "${OS_RELEASE_ETC}" -ef "${OS_RELEASE_USR}" ]]; then
    OS_RELEASE_FILES+=("${OS_RELEASE_ETC}")
fi

osr_set() {
    local key="$1" value="$2" file
    for file in "${OS_RELEASE_FILES[@]}"; do
        sed -i "/^${key}=/d" "${file}"
        printf '%s="%s"\n' "${key}" "${value}" >> "${file}"
    done
}

osr_unset() {
    local key="$1" file
    for file in "${OS_RELEASE_FILES[@]}"; do
        sed -i "/^${key}=/d" "${file}"
    done
}

# Pasiv Black Box is the resulting product identity. Home Server Base is the
# direct parent while AlmaLinux remains the upstream package/kernel foundation.
osr_set NAME "Pasiv Black Box"
osr_set PRETTY_NAME "Pasiv Black Box 10"
osr_set ID "pasiv-black-box"
osr_set ID_LIKE "almalinux rhel centos fedora"
osr_set VERSION "${BASE_VERSION_ID}"
osr_set VARIANT "Pasiv Black Box"
osr_set VARIANT_ID "pasiv-black-box"
osr_set IMAGE_ID "pasiv-black-box"
osr_set IMAGE_VERSION "10"
osr_set HOME_URL "https://github.com/highwaytoit/pasiv-black-box"
osr_set DOCUMENTATION_URL "https://github.com/highwaytoit/pasiv-black-box/tree/main/docs"
osr_set SUPPORT_URL "https://github.com/highwaytoit/pasiv-black-box/issues"
osr_set BUG_REPORT_URL "https://github.com/highwaytoit/pasiv-black-box/issues"
osr_set VENDOR_NAME "Highway to IT"
osr_set VENDOR_URL "https://github.com/highwaytoit"
osr_set CPE_NAME "cpe:/o:highwaytoit:pasiv-black-box:10"

# Preserve the direct Home Server Base parent identity. The inherited
# HOME_SERVER_BASE_UPSTREAM_* fields retain the AlmaLinux provenance chain.
osr_set PASIV_BLACK_BOX_BASE_ID "${BASE_ID}"
osr_set PASIV_BLACK_BOX_BASE_PRETTY_NAME "${BASE_PRETTY_NAME}"
osr_set PASIV_BLACK_BOX_BASE_VERSION_ID "${BASE_VERSION_ID}"
osr_set PASIV_BLACK_BOX_BASE_PLATFORM_ID "${BASE_PLATFORM_ID}"
osr_set PASIV_BLACK_BOX_BASE_CPE_NAME "${BASE_CPE_NAME}"
osr_set PASIV_BLACK_BOX_BASE_PROFILE "${BASE_PROFILE}"
osr_set PASIV_BLACK_BOX_BASE_CHANNEL "${BASE_CHANNEL}"

# These upstream support/vendor fields describe AlmaLinux itself, not this
# downstream combined image. Namespaced base metadata above keeps provenance.
for key in \
    ALMALINUX_MANTISBT_PROJECT \
    ALMALINUX_MANTISBT_PROJECT_VERSION \
    REDHAT_SUPPORT_PRODUCT \
    REDHAT_SUPPORT_PRODUCT_VERSION \
    SUPPORT_END \
    LOGO; do
    osr_unset "${key}"
done

chmod 0644 "${OS_RELEASE_FILES[@]}"

# Verify the completed image trusts its canonical package path.
jq empty /etc/containers/policy.json
test -f /usr/lib/pki/containers/highwaytoit.pub
test -f /etc/containers/registries.d/ghcr.io-highwaytoit.yaml
grep -Fq "${IMAGE_REPOSITORY}:" /etc/containers/registries.d/ghcr.io-highwaytoit.yaml
grep -Fq "use-sigstore-attachments: true" /etc/containers/registries.d/ghcr.io-highwaytoit.yaml
