ARG HOME_SERVER_BASE_IMAGE=ghcr.io/home-server-project/home-server-base-10:stable
ARG UPSIDE_PACKAGE_IMAGE=ghcr.io/home-server-project/cockpit-upside:stable
ARG IMAGE_REPOSITORY=ghcr.io/highwaytoit/pasiv-black-box

FROM scratch AS ctx
COPY build_files /build_files
COPY system_files /system_files
COPY quadlets /quadlets
COPY docs /docs
COPY cosign.pub /cosign.pub

# UPSide is built and validated by the Home Server Packages project. Pasiv
# consumes only the published RPM artifact resolved to an exact digest by CI.
FROM ${UPSIDE_PACKAGE_IMAGE} AS upside-package

FROM ${HOME_SERVER_BASE_IMAGE}
ARG IMAGE_REPOSITORY

LABEL containers.bootc=1 \
      ostree.bootable=1 \
      org.opencontainers.image.vendor="Home Server Project" \
      io.highwaytoit.pasiv-black-box.base="home-server-base-10" \
      io.highwaytoit.pasiv-black-box.base-channel="stable" \
      io.highwaytoit.pasiv-black-box.base-profile="almalinux-10-minimal-plus"
RUN bootc container lint --fatal-warnings
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]

LABEL org.opencontainers.image.title="Pasiv Black Box" \
      org.opencontainers.image.description="Purpose-built Home Server Base 10 monitoring and infrastructure supervision appliance" \
      org.opencontainers.image.source="https://github.com/highwaytoit/pasiv-black-box" \
      org.opencontainers.image.vendor="Highway to IT" \
      io.highwaytoit.pasiv-black-box.base="home-server-base-10" \
      io.highwaytoit.pasiv-black-box.base-channel="stable" \
      io.highwaytoit.pasiv-black-box.base-profile="almalinux-10-minimal-plus"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=upside-package,source=/rpms,target=/upside-rpm \
    --mount=type=tmpfs,dst=/run \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_REPOSITORY="${IMAGE_REPOSITORY}" \
    /ctx/build_files/build.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,dst=/tmp \
    IMAGE_REPOSITORY="${IMAGE_REPOSITORY}" \
    /ctx/build_files/finalize-image.sh

RUN /usr/libexec/pasiv-black-box/health/identity \
    && bootc container lint --fatal-warnings
