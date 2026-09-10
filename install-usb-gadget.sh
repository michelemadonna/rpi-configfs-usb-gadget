#!/usr/bin/env bash

set -Eeuo pipefail

readonly BOOT_DIR="/boot/firmware"
readonly INTERFACES_FILE="${BOOT_DIR}/interfaces"
readonly MARKER="/var/lib/usb-gadget/.offline-firstboot-installed"
readonly REEXECUTED_SCRIPT="/run/usb-gadget-firstboot.sh"

log() {
    printf '[usb-gadget-firstboot] %s\n' "$*"
}

die() {
    printf '[usb-gadget-firstboot] ERROR: %s\n' "$*" >&2
    exit 1
}

remove_firstboot_hook() {

    [[ -f "$INTERFACES_FILE" ]] ||
        die "ifupdown configuration not found: $INTERFACES_FILE"

    local temporary

    temporary="$(mktemp "${INTERFACES_FILE}.tmp.XXXXXX")"

    awk '
        $0 !~ /^[[:space:]]*up[[:space:]]+\/bin\/bash[[:space:]]+\/boot\/firmware\/install-usb-gadget[.]sh[[:space:]]+--offline-firstboot[[:space:]]+\|\|[[:space:]]+true[[:space:]]*$/ {
            print
        }
    ' "$INTERFACES_FILE" > "$temporary"

    mv "$temporary" "$INTERFACES_FILE"
}

install_runtime_files() {

    [[ -r "${BOOT_DIR}/usb-gadget" ]] ||
        die "Missing ${BOOT_DIR}/usb-gadget"

    [[ -r "${BOOT_DIR}/usb-gadget.service" ]] ||
        die "Missing ${BOOT_DIR}/usb-gadget.service"

    [[ -r "${BOOT_DIR}/usb-gadget.conf" ]] ||
        die "Missing ${BOOT_DIR}/usb-gadget.conf"

    install -d -m 0755 /usr/local/sbin /etc/systemd/system

    install -m 0755 \
        "${BOOT_DIR}/usb-gadget" \
        /usr/local/sbin/usb-gadget

    install -m 0644 \
        "${BOOT_DIR}/usb-gadget.service" \
        /etc/systemd/system/usb-gadget.service
}

main() {

    [[ "$#" -eq 1 && "$1" == "--offline-firstboot" ]] ||
        die "Usage: $0 --offline-firstboot"

    [[ "$EUID" -eq 0 ]] ||
        die "This installer must run as root"

    [[ -e "$MARKER" ]] && {
        log "First-boot installation already completed"
        exit 0
    }

    # The service may unmount /boot/firmware when boot storage is enabled.
    # Re-exec from the root filesystem first, so this process no longer has
    # the installer script or its working directory on the boot mount.
    if [[ "${USB_GADGET_FIRSTBOOT_REEXEC:-0}" != 1 ]]; then
        install -m 0755 "$0" "$REEXECUTED_SCRIPT"
        cd /
        USB_GADGET_FIRSTBOOT_REEXEC=1 exec "$REEXECUTED_SCRIPT" "$@"
    fi

    [[ -d "$BOOT_DIR" ]] ||
        die "Boot mount not found: $BOOT_DIR"

    log "Installing USB gadget files from ${BOOT_DIR}"

    install_runtime_files
    # Remove the bootstrap before starting the gadget service: the service
    # may unmount the boot partition when boot storage is enabled.
    remove_firstboot_hook

    systemctl daemon-reload
    systemctl enable usb-gadget.service
    systemctl start usb-gadget.service

    install -d -m 0755 "$(dirname "$MARKER")"
    : > "$MARKER"

    sync
    log "USB gadget installed and started on the first boot"
}

main "$@"
