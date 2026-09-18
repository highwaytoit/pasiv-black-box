# Pasiv Black Box

[![stable](https://github.com/highwaytoit/pasiv-black-box/actions/workflows/build.yml/badge.svg)](https://github.com/highwaytoit/pasiv-black-box/actions/workflows/build.yml)
[![testing](https://github.com/highwaytoit/pasiv-black-box/actions/workflows/build-testing.yml/badge.svg)](https://github.com/highwaytoit/pasiv-black-box/actions/workflows/build-testing.yml)

Pasiv Black Box is a small, purpose-built bootc monitoring and infrastructure-supervision appliance built on [Home Server Base 10](https://github.com/home-server-project/home-server-base-10), with AlmaLinux OS 10 as the upstream Enterprise Linux foundation.

It is intentionally not a general-purpose server distribution. The host is kept focused on infrastructure supervision, UPS and power integration, networking, hardware diagnostics, and the native components needed to support containerized monitoring services.

> [!IMPORTANT]
> Pasiv Black Box is still under active development. It is suitable for VM testing and lab use, and it is also being exercised on real hardware, but changes may still affect image composition and deployment behavior.

## Upstream foundation

Pasiv Black Box consumes [Home Server Base 10](https://github.com/home-server-project/home-server-base-10) as its direct bootc parent. Home Server Base 10 owns the shared AlmaLinux 10 Minimal Plus composition and generic base behavior. AlmaLinux OS 10 remains the upstream Enterprise Linux source for the kernel, core packages, and EL10 compatibility layer.

Pasiv Black Box adds the appliance-specific configuration, monitoring-host tooling, UPS and power integration, networking, diagnostics, update behavior, image signing, and supplied Quadlet library.

```text
AlmaLinux OS 10
      |
      v
Home Server Base 10
      |
      v
Pasiv Black Box
      |
      +-- UPS / power
      +-- networking
      +-- host diagnostics
      +-- Cockpit bridge
      +-- Podman
      +-- Quadlets library
```

Pasiv Black Box is an independent community project and is not affiliated with or endorsed by the AlmaLinux OS Foundation.

## What Pasiv Black Box is for

Pasiv Black Box is designed to supervise infrastructure and physical hosts rather than to become another all-purpose application server.

The host layer keeps services close to the hardware when that is useful or necessary, while replaceable monitoring applications are expected to run as Podman Quadlets.

### Native host layer

| Area | Included |
| --- | --- |
| UPS / power | NUT, UPSide, PowerTOP |
| Networking | NetworkManager, firewalld, Tailscale, NetBird, WireGuard tools |
| Administration | Cockpit bridge/pages, Micro, btop, tmux, jq |
| Hardware | firmware, fwupd, SMART, NVMe, sensors, USB/PCI tools |
| Containers | Podman and systemd Quadlets |
| Diagnostics | tcpdump, dig, traceroute, nc, iperf3 |

The native distro package set is defined in [`build_files/software.env`](build_files/software.env). Third-party package details are maintained in [Home Server Packages](https://github.com/home-server-project/home-server-packages).

## Intentionally not included

Pasiv Black Box deliberately avoids turning the host into a kitchen-sink server image.

It does not include a built-in virtualization stack, Docker, Docker Compose, ZFS, mergerfs, Samba/NFS server roles, or a baked-in Prometheus/Grafana/Loki application stack.

Replaceable monitoring applications belong in Podman Quadlets rather than in the host image.

## Administrative access

Pasiv Black Box follows an appliance-style administration model.

- SSH is enabled.
- Members of the `wheel` group have passwordless sudo.
- Cockpit system components are installed natively.
- The browser-facing Cockpit web service is supplied as a Quadlet template and is not automatically activated.

The system-wide interactive Bash prompt keeps the standard RHEL-style shape with a dark-red `user@host` identity.

## Networking and remote access

The image includes NetworkManager, firewalld, systemd-resolved, WireGuard tooling, Tailscale, and NetBird.

Tailscale and NetBird are installed but are not automatically enrolled. Remote-access identity, keys, and network policy remain deployment-specific.

## UPS and monitoring role

NUT and UPSide are included natively because UPS monitoring, host shutdown, USB access, and power-state handling belong to the host operating system.

The generic image does not contain site-specific UPS configuration, usernames/passwords, shutdown thresholds, Wake-on-LAN targets, or recovery policy.

See [`docs/NUT-UPSide.md`](docs/NUT-UPSide.md) for the local deployment model.

## Images and release channels

### Stable

```text
ghcr.io/highwaytoit/pasiv-black-box:10
```

### Testing

```text
ghcr.io/highwaytoit/pasiv-black-box:testing
```

Immutable build tags are also published:

```text
ghcr.io/highwaytoit/pasiv-black-box:10-YYYYMMDD-abcdef1
ghcr.io/highwaytoit/pasiv-black-box:testing-YYYYMMDD-abcdef1
```

| Channel | Moving tag | Branch | Schedule |
| --- | --- | --- | --- |
| Stable | `:10` | `main` | Friday 15:35 UTC |
| Testing | `:testing` | `testing` | Daily 14:35 UTC |

The stable channel is intended for the normal deployment path. The testing channel exists for validating upcoming changes before they reach stable.

Stable performs its own complete build and validation. A Stable image and GitHub Release are published only by the scheduled Stable workflow or a manual **Run workflow** invocation on `main`. Pull requests validate only; ordinary pushes or merges to `main` do not publish Stable artifacts.

Testing immutable `testing-*` image versions older than 45 days are eligible for automatic cleanup while at least seven recent tagged testing builds are retained. The moving `:testing` tag is preserved.

Stable immutable `10-*` image versions and matching GitHub Releases become eligible for cleanup only after 45 days, while at least the newest seven are retained. The moving `:10` tag is preserved. When an expired Stable GitHub Release is retired, its matching Git tag is removed with it.

## Updates

Pasiv Black Box uses bootc for image updates.

The supplied update timer stages updates automatically but does not automatically reboot the machine. The administrator stays in control of when a staged deployment becomes active.

Useful commands:

```bash
sudo bootc status
sudo bootc upgrade
```

To switch an existing installation to the canonical image:

```bash
sudo bootc switch ghcr.io/highwaytoit/pasiv-black-box:10
```

## Image signing and releases

Published images are signed with Cosign.

Testing publishes the moving `:testing` tag and immutable `testing-YYYYMMDD-<git-sha>` tags, but does not create GitHub Releases.

A successful scheduled or manually dispatched Stable workflow publishes the moving `:10` tag, an immutable `10-YYYYMMDD-<git-sha>` tag, verifies the published signature, and then creates or updates the matching GitHub Release.

The image installs its own container-signature trust configuration so bootc and containers/image can verify the canonical `ghcr.io/highwaytoit/pasiv-black-box` repository.

The public signing key is stored in this repository as [`cosign.pub`](cosign.pub).

## Installer ISO

The installation ISO is maintained separately from the operating-system image.

The current installer work remains in its own repository and is intentionally not coupled to the image cleanup in this repository. Hostname and initial-user choices belong to the installer/deployment layer, not to the generic Pasiv Black Box image.

## Local documentation

Every image installs local documentation and supplied Quadlet templates under:

```text
/usr/share/pasiv-black-box/doc/
/usr/share/pasiv-black-box/quadlets/
```

Supplied Quadlets are templates only. They are deliberately kept outside Podman's active Quadlet search directories until the administrator chooses to deploy them.

See:

- [`docs/README.md`](docs/README.md)
- [`docs/QUADLETS.md`](docs/QUADLETS.md)
- [`docs/NUT-UPSide.md`](docs/NUT-UPSide.md)

## Validation status

The image build validates the bootc container, required host packages, image-signature trust, systemd-resolved integration, supplied documentation and Quadlets, and the Pasiv Black Box operating-system identity.

Pasiv Black Box is also being exercised on a Lenovo ThinkCentre M715q with an AMD Ryzen 3 PRO 2200GE as a monitoring node.

## About the name

**Pasiv** is intentional.

If you know why a small black box might connect several sleeping minds to the same shared world, you probably already understand the name.

Just don't fall asleep.

For everyone else, it is simply a black box.

## Upstream and references

Pasiv Black Box depends on and benefits from several upstream projects, including:

- [Home Server Base 10](https://github.com/home-server-project/home-server-base-10)
- [AlmaLinux OS](https://almalinux.org/)
- [bootc](https://github.com/bootc-dev/bootc)
- [Podman](https://podman.io/)
- [Cockpit](https://cockpit-project.org/)
- [Network UPS Tools](https://networkupstools.org/)
- [UPSide](https://github.com/deviationist/cockpit-upside)
- [Home Server Packages](https://github.com/home-server-project/home-server-packages)
- [Tailscale](https://tailscale.com/)
- [NetBird](https://netbird.io/)

Third-party source and attribution details are recorded in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## License

See [`LICENSE`](LICENSE).
