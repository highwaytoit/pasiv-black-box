# Third-party notices

## Realtek USB Ethernet udev rule

`system_files/usr/lib/udev/rules.d/50-usb-realtek-net.rules` is carried from the Universal Blue `ublue-os/packages` project, which tracks the rule source from `bb-qq/r8152`.

Sources:

- https://github.com/ublue-os/packages/blob/main/packages/ublue-os-udev-rules/src/udev-rules.d/50-usb-realtek-net.rules
- https://github.com/bb-qq/r8152

Keep this attribution with the copied rule and review upstream changes before updating it.

## UPSide

UPSide is consumed as the verified `cockpit-upside` RPM published by the Home Server Project package repository:

- https://github.com/home-server-project/home-server-packages
- https://github.com/deviationist/cockpit-upside

Pasiv Black Box resolves the published stable package artifact to an exact digest during its image build. UPSide source builds, tests, license handling, and package publication are owned by `home-server-packages` rather than repeated inside this repository.

## uBlue Brew and Homebrew

Pasiv Black Box consumes the uBlue Brew bootc integration from:

- https://github.com/ublue-os/brew

Each image build resolves the current uBlue Brew image to an exact digest and verifies it with
uBlue's signing key before composition. The integration supplies the Homebrew bootstrap payload,
systemd units, and shell integration used by both Pasiv CPU-baseline image lines.

uBlue Brew creates its payload using the official Homebrew Linux installer. Homebrew itself is
maintained upstream at:

- https://github.com/Homebrew/brew
