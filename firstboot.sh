#!/bin/bash
#
# firstboot.sh — bootstrap per l'installazione automatica al primo avvio.
#
# Non installa nulla direttamente: al primo avvio la rete non è ancora pronta
# e apt fallirebbe. Crea invece un servizio one-shot che attende la rete,
# lancia install.sh e poi si disattiva da solo.
#
# Va richiamato dal firstrun.sh scritto da Raspberry Pi Imager. Vedi README.
#
set +e

if [ -d /boot/firmware/usb-video-player ]; then
	SRC=/boot/firmware/usb-video-player
else
	SRC=/boot/usb-video-player
fi

cat >/etc/systemd/system/usb-video-player-setup.service <<EOF
[Unit]
Description=Installazione iniziale USB Video Player
After=network-online.target
Wants=network-online.target
ConditionPathExists=$SRC/install.sh

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash $SRC/install.sh
# si disattiva solo se l'installazione è andata a buon fine;
# altrimenti riprova al riavvio successivo
ExecStartPost=/bin/systemctl disable usb-video-player-setup.service
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl enable usb-video-player-setup.service
exit 0
