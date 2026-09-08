# Raspberry Pi Zero 2 W USB Gadget / Host Mode

This package configures the Pi Zero 2 W OTG controller in one of two mutually exclusive modes:

- `USB_MODE=gadget`: the Pi acts as a USB peripheral toward macOS/Linux/Windows.
- `USB_MODE=host`: the Pi acts as a USB host for external USB devices such as Wi-Fi dongles or hubs.

The same OTG controller cannot be host and gadget at the same time.

## Files to copy to the boot partition

```text
install-usb-gadget.sh
usb-gadget
usb-gadget.service
usb-gadget.conf
```

`usb-gadget.conf` stays on the boot partition and is the configuration source of truth.

## Gadget mode: macOS/Linux

```bash
USB_MODE=gadget
PROFILE=ecm
```

This can expose:

- CDC ECM Ethernet
- optional CDC ACM serial
- optional real boot partition as USB Mass Storage
- persistent MAC addresses
- static IPv4 on the Pi USB interface

## Gadget mode: Windows

```bash
USB_MODE=gadget
PROFILE=rndis
```

## USB host mode

```bash
USB_MODE=host
```

The installer configures the Device Tree overlay in `config.txt`:

```text
dtoverlay=dwc2,dr_mode=host
```

In gadget mode it uses:

```text
dtoverlay=dwc2,dr_mode=peripheral
```

A reboot is required when switching roles.

## Offline installation from macOS

Copy all four package files to the Raspberry Pi boot partition.

Append the following arguments to the single line in `cmdline.txt`:

```text
systemd.run="/bin/bash /boot/firmware/install-usb-gadget.sh --offline-firstboot" systemd.run_success_action=none systemd.run_failure_action=none
```

If your distribution mounts the boot partition at `/boot`, use `/boot/install-usb-gadget.sh`.

Then eject the boot volume cleanly and boot the Pi.

The first boot:

1. validates the package,
2. backs up `cmdline.txt` and `config.txt`,
3. removes legacy `g_ether` parameters,
4. ensures `modules-load=dwc2`,
5. sets the selected OTG role in `config.txt`,
6. installs `/usr/local/sbin/usb-gadget`,
7. installs/enables `usb-gadget.service`,
8. removes temporary `systemd.run=...` parameters,
9. reboots.

The selected USB mode becomes active on the second boot.

## Normal installation from Linux

```bash
sudo ./install-usb-gadget.sh
sudo reboot
```

## Switching between gadget and host later

Edit `usb-gadget.conf` on the boot partition.

For USB host:

```bash
USB_MODE=host
```

Then:

```bash
sudo /boot/firmware/install-usb-gadget.sh
sudo reboot
```

To return to ECM gadget mode:

```bash
USB_MODE=gadget
PROFILE=ecm
```

Then rerun the installer and reboot.

## Persistent MAC addresses

On the first successful gadget start:

```text
/var/lib/usb-gadget/identity.conf
```

is created. The same MAC addresses are reused after reboot.

## Boot partition export safety

When `ENABLE_BOOT_STORAGE=yes`, the boot filesystem is unmounted locally before its raw block device is exposed over USB.

Never mount the same filesystem read/write on the Pi and the USB host simultaneously.

Always eject the boot volume cleanly from macOS before rebooting the Pi.

## Useful commands

```bash
sudo /boot/firmware/install-usb-gadget.sh --check
sudo systemctl status usb-gadget
sudo /usr/local/sbin/usb-gadget status
```
       └── real boot partition
           /dev/mmcblk0p1
```

For Windows, change the Ethernet profile from ECM to RNDIS.

## Requirements

The kernel must support the following options:

```text
CONFIG_USB_LIBCOMPOSITE
CONFIG_USB_CONFIGFS
CONFIG_USB_CONFIGFS_ECM
CONFIG_USB_CONFIGFS_RNDIS
CONFIG_USB_CONFIGFS_ACM
CONFIG_USB_CONFIGFS_MASS_STORAGE
```

On Kali/Raspberry Pi kernels these can be checked with:

```bash
grep -E 'CONFIG_USB_(LIBCOMPOSITE|CONFIGFS|CONFIGFS_ECM|CONFIGFS_RNDIS|CONFIGFS_ACM|CONFIGFS_MASS_STORAGE)' \
    /boot/config-$(uname -r)
```

The Raspberry Pi USB controller must be running in device/gadget mode through `dwc2`.

## Installation

Copy the installer to the Raspberry Pi and run:

```bash
chmod +x install-usb-gadget.sh
sudo ./install-usb-gadget.sh
```

The installer:

1. Detects `cmdline.txt`.
2. Creates a timestamped backup of it.
3. Removes legacy `g_ether` parameters.
4. Configures `modules-load=dwc2`.
5. Checks ConfigFS/libcomposite support.
6. Detects the boot partition and its mount point where possible.
7. Installs `/usr/local/sbin/usb-gadget`.
8. Creates `/etc/usb-gadget/gadget.conf` if it does not already exist.
9. Installs and enables `usb-gadget.service`.
10. Leaves the system ready for a reboot.

Then reboot:

```bash
sudo reboot
```

After reboot:

```bash
sudo usb-gadget status
```

or:

```bash
systemctl status usb-gadget.service
```

## Configuration

The main configuration file is:

```text
/etc/usb-gadget/gadget.conf
```

Default configuration:

```bash
PROFILE=ecm

ENABLE_ACM=yes

ENABLE_BOOT_STORAGE=yes
BOOT_STORAGE_DEVICE=/dev/mmcblk0p1
BOOT_STORAGE_MOUNT=/boot/firmware
BOOT_STORAGE_RO=no

USB_ADDRESS=192.168.2.3/24

MANUFACTURER="Kali Linux"
PRODUCT="Raspberry Pi Zero 2 W"

ID_VENDOR=0x1d6b
ID_PRODUCT=0x0104
BCD_DEVICE=0x0100
BCD_USB=0x0200
MAX_POWER_MA=250
```

Verify the boot partition before relying on the defaults:

```bash
lsblk -f
findmnt /boot
findmnt /boot/firmware
```

## Persistent MAC addresses

On the first successful start, the runtime script generates two locally administered unicast MAC addresses and stores them in:

```text
/var/lib/usb-gadget/identity.conf
```

Example:

```text
HOST_MAC=02:43:c8:82:b1:10
DEV_MAC=02:55:32:77:bc:a2
SERIAL=000000001234abcd
```

These values survive reboots and profile changes.

To deliberately create a new USB identity:

```bash
sudo systemctl stop usb-gadget
sudo rm /var/lib/usb-gadget/identity.conf
sudo systemctl start usb-gadget
```

Do not delete this file during normal upgrades or reboots if you want macOS/Windows to continue seeing the same Ethernet device.

## macOS / Linux profile

Use:

```bash
PROFILE=ecm
```

Restart the gadget after changing the profile:

```bash
sudo systemctl restart usb-gadget
```

The Raspberry Pi receives:

```text
192.168.2.3/24
```

No default route is added through USB, so Wi-Fi can remain the normal Internet/default route.

On macOS, identify the new Ethernet interface:

```bash
networksetup -listallhardwareports
```

For a direct static test, assuming the interface is `en6`:

```bash
sudo ifconfig en6 inet 192.168.2.1 netmask 255.255.255.0 up
ping 192.168.2.3
```

From the Raspberry Pi:

```bash
ping 192.168.2.1
```

## Windows profile

Edit:

```text
/etc/usb-gadget/gadget.conf
```

and change:

```bash
PROFILE=rndis
```

Then restart:

```bash
sudo systemctl restart usb-gadget
```

ECM and RNDIS are intentionally implemented as alternative profiles rather than exposing both Ethernet functions simultaneously. This keeps host behavior deterministic.

## CDC ACM serial

With:

```bash
ENABLE_ACM=yes
```

the Raspberry Pi exposes:

```text
/dev/ttyGS0
```

On macOS the corresponding device normally appears as something similar to:

```bash
ls /dev/cu.usbmodem*
```

This provides a useful fallback management channel even if USB Ethernet is not working.

## Boot partition as USB Mass Storage

With:

```bash
ENABLE_BOOT_STORAGE=yes
BOOT_STORAGE_DEVICE=/dev/mmcblk0p1
BOOT_STORAGE_RO=no
```

the real boot partition is exposed directly to the USB host.

Before creating the USB Mass Storage LUN, the runtime script:

1. Calls `sync`.
2. Detects whether the boot partition is mounted.
3. Unmounts it from the Raspberry Pi.
4. Verifies that it is no longer mounted.
5. Exposes the block device through ConfigFS Mass Storage.

When the gadget is stopped, the script removes the Mass Storage backing device and remounts the boot partition.

### Important data-integrity rule

Never mount the same filesystem read/write simultaneously on both the Raspberry Pi and the USB host.

The script prevents the normal Raspberry Pi mount from remaining active while the partition is exported, but the host must still flush/eject the USB volume before rebooting or stopping the gadget.

On macOS, eject the volume in Finder or use:

```bash
diskutil list
diskutil eject /dev/diskX
```

Then reboot the Raspberry Pi if required.

If you only need to inspect the boot partition from the host, set:

```bash
BOOT_STORAGE_RO=yes
```

## Service commands

Start:

```bash
sudo systemctl start usb-gadget
```

Stop:

```bash
sudo systemctl stop usb-gadget
```

Restart:

```bash
sudo systemctl restart usb-gadget
```

Status:

```bash
sudo usb-gadget status
```

Logs:

```bash
journalctl -u usb-gadget.service -b
```

Follow logs live:

```bash
journalctl -fu usb-gadget.service
```

## Files installed

```text
/etc/usb-gadget/gadget.conf
/usr/local/sbin/usb-gadget
/etc/systemd/system/usb-gadget.service
/var/lib/usb-gadget/identity.conf
```

The identity file is created only when the gadget starts for the first time.

## Legacy `g_ether`

Do not load `g_ether` together with this setup.

The kernel command line should contain:

```text
modules-load=dwc2
```

and must not contain:

```text
g_ether
g_ether.host_addr=...
g_ether.dev_addr=...
```

`g_ether` and the ConfigFS gadget would otherwise compete for the same USB Device Controller.

## Troubleshooting

### Check the USB Device Controller

```bash
ls /sys/class/udc
```

A Pi Zero 2 W typically shows an entry corresponding to the `dwc2` controller.

### Check loaded modules

```bash
lsmod | grep -E 'dwc2|libcomposite|usb_f_ecm|usb_f_rndis|usb_f_acm|usb_f_mass_storage'
```

### Check ConfigFS

```bash
mount | grep configfs
ls /sys/kernel/config/usb_gadget
```

### Check the gadget tree

```bash
find /sys/kernel/config/usb_gadget/pizero -maxdepth 4 -print
```

### Check the USB Ethernet interface

```bash
ip -br link
ip -br addr
```

### Check ARP traffic

On the Raspberry Pi:

```bash
sudo tcpdump -eni usb0 arp
```

On macOS, replacing `en6` as needed:

```bash
sudo tcpdump -eni en6 arp
```

### Check boot partition state

```bash
findmnt -S /dev/mmcblk0p1
lsblk -f
```

When Mass Storage is active, the boot partition should normally be unmounted on the Raspberry Pi.

### Check systemd logs

```bash
journalctl -u usb-gadget.service -b --no-pager
```

## Notes on VID/PID

The supplied configuration uses Linux Foundation-style IDs for personal/lab use. For a product intended for distribution, use a properly assigned USB Vendor ID and Product ID.

## Tested design goal

The configuration is intended specifically to avoid relying on the legacy `g_ether` automatic behavior. The host-facing Ethernet function is explicitly selected through ConfigFS:

```text
macOS/Linux -> CDC ECM
Windows     -> RNDIS
```

while ACM and Mass Storage can remain part of the same composite gadget.
