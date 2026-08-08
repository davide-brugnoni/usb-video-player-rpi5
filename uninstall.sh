#!/usr/bin/env bash
#
# uninstall.sh — rimuove usb-video-player
# Uso: sudo ./uninstall.sh
#
set -uo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Esegui con sudo."; exit 1; }

systemctl disable --now usb-video-player.service 2>/dev/null

# smonta eventuali chiavette rimaste montate
for mp in /media/usbvideo/*; do
	mountpoint -q "$mp" 2>/dev/null && umount -l "$mp"
	rmdir "$mp" 2>/dev/null
done

rm -f /etc/systemd/system/usb-video-player.service
rm -f /usr/local/bin/usb-video-player.sh
rm -rf /usr/local/share/usb-video-player /run/usb-video-player
rmdir /media/usbvideo 2>/dev/null

# il comportamento del pulsante di accensione torna al default di sistema
rm -f /etc/systemd/logind.conf.d/10-powerbutton.conf

systemctl daemon-reload
systemctl restart systemd-logind

echo "Rimosso. I pacchetti installati (mpv, imagemagick, ecc.) restano sul sistema."
