# Security Policy

## Scope

This project configures a Raspberry Pi Zero 2 W as a ConfigFS USB gadget. It
is intended for personal, laboratory, and controlled field environments. It
is not a hardened security appliance.

The following files are security-sensitive:

- `install-usb-gadget.sh`, which runs as root during first boot;
- `usb-gadget`, which runs as root through systemd;
- `usb-gadget.service`;
- `usb-gadget.conf`, which is sourced as shell code;
- the FAT boot partition and its boot configuration files.

## Trust model

The boot partition is trusted input. Anyone who can modify it can replace the
installer, runtime script, service, configuration, kernel parameters, or boot
configuration and may execute code as root on the next boot.

Do not use an untrusted SD card, boot volume, USB host, or configuration file
with this package.

`usb-gadget.conf` is intentionally sourced as a Bash configuration file. Do
not copy untrusted values into it without reviewing them first.

## USB Mass Storage risks

With:

```bash
ENABLE_BOOT_STORAGE=yes
```

the Pi unmounts the boot filesystem and exports its raw block device to the
USB host. The host can then read or modify boot files according to:

```bash
BOOT_STORAGE_RO=yes|no
```

Use `BOOT_STORAGE_RO=yes` when the host does not need to modify the boot
partition. Always eject the exported volume cleanly before rebooting or
stopping the gadget. Never mount the same filesystem read/write on both the Pi
and the USB host at the same time; doing so can corrupt the filesystem.

If the boot partition must not be exposed at all, use:

```bash
ENABLE_BOOT_STORAGE=no
```

## Network and authentication

The USB Ethernet interface is a network connection, not an authentication
boundary. Configure SSH and other services using the normal security controls
of the operating system. Use strong credentials or SSH keys, and do not expose
unnecessary services on the USB network.

`USB_GATEWAY` changes the Pi's default route to the USB host. If Internet
Sharing is enabled on that host, the host becomes part of the Pi's trust and
network path. Set `USB_DNS` only to DNS servers you trust; leave it empty to
preserve the existing DNS configuration.

The USB gadget uses the Linux Foundation laboratory VID/PID values in the
sample configuration. They are suitable for personal or laboratory use only;
use assigned identifiers for a product or deployed commercial device.

## First-boot precautions

Before first boot, review all files copied to the boot partition and remove
legacy `g_ether` and experimental systemd boot parameters from `cmdline.txt`.
The first-boot hook is deliberately powerful because it installs files into
the root filesystem and starts a root service.

Keep the one-shot marker and first-boot hook under review when recovering an
incomplete installation:

```text
/var/lib/usb-gadget/.offline-firstboot-installed
/boot/firmware/interfaces
```

## Reporting a vulnerability

Please do not publish sensitive exploit details in a public issue.

Use GitHub's private vulnerability reporting or Security Advisory workflow for
this repository when available. If private reporting is not enabled, open a
minimal public issue asking for a private contact channel and do not include
credentials, private IP addresses, or working exploit code.

Include, where safe:

- the affected commit or file version;
- the Raspberry Pi and operating-system version;
- the configuration required to reproduce the issue;
- the impact and any available mitigation.

This is a personal/laboratory project and does not promise a fixed response
time or security-support lifetime.
