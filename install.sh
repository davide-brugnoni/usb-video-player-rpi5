#!/usr/bin/env bash
#
# install.sh — installa usb-video-player su Raspberry Pi OS Lite (Pi 5)
# Uso: sudo ./install.sh
#
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Esegui con sudo."; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "== Pacchetti =="
apt-get update
apt-get install -y mpv exfatprogs ntfs-3g imagemagick alsa-utils util-linux fonts-dejavu-core

echo "== File =="
install -m 755 "$HERE/usb-video-player.sh"      /usr/local/bin/usb-video-player.sh
install -m 644 "$HERE/usb-video-player.service" /etc/systemd/system/usb-video-player.service
mkdir -p /usr/local/share/usb-video-player /media/usbvideo

echo "== Immagine di avviso =="
IMG=/usr/local/share/usb-video-player/no-media.png
TEXT=$'Inserire una chiavetta USB\ncon video compatibili'
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf

if command -v magick >/dev/null 2>&1; then
	IM=magick
elif command -v convert >/dev/null 2>&1; then
	IM=convert
else
	IM=""
fi

if [ -n "$IM" ]; then
	"$IM" -size 1920x1080 xc:black \
		-font "$FONT" -pointsize 72 -fill white \
		-gravity center -interline-spacing 24 \
		-annotate +0+0 "$TEXT" "$IMG"
else
	ffmpeg -y -loglevel error -f lavfi -i color=c=black:s=1920x1080 \
		-vf "drawtext=fontfile=$FONT:text='Inserire una chiavetta USB':fontcolor=white:fontsize=72:x=(w-text_w)/2:y=(h/2)-90,drawtext=fontfile=$FONT:text='con video compatibili':fontcolor=white:fontsize=72:x=(w-text_w)/2:y=(h/2)+10" \
		-frames:v 1 "$IMG"
fi
chmod 644 "$IMG"

echo "== Pulsante di accensione =="
# Pressione breve del pulsante interno del Pi 5 = spegnimento pulito.
# Su Raspberry Pi OS Lite è già il comportamento predefinito: questo drop-in
# lo rende esplicito e lo mantiene anche su immagini con desktop.
mkdir -p /etc/systemd/logind.conf.d
cat >/etc/systemd/logind.conf.d/10-powerbutton.conf <<'EOF'
[Login]
HandlePowerKey=poweroff
PowerKeyIgnoreInhibited=yes
EOF
systemctl restart systemd-logind

echo "== Servizio =="
systemctl daemon-reload
systemctl enable --now usb-video-player.service

echo
echo "Fatto. Video e audio sono forzati su HDMI A (porta vicina all'alimentazione)."
echo "Spegnimento: pressione breve del pulsante interno del Pi 5."
echo "Log in tempo reale:  journalctl -u usb-video-player -f"
