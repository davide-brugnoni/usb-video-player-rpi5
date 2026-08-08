#!/usr/bin/env bash
#
# usb-video-player.sh
# Raspberry Pi 5 / Raspberry Pi OS Lite (senza interfaccia grafica)
#
# - monta automaticamente le chiavette USB collegate (sola lettura)
# - cerca tutti i file video, li ordina in modo alfabetico/numerico naturale
# - mostra un countdown di 10 secondi con il numero di video trovati
# - li riproduce in loop infinito con mpv, video e audio sempre su HDMI A
# - se non trova chiavette o video compatibili mostra un'immagine di avviso
# - rileva a caldo inserimento/rimozione della chiavetta e riparte da solo
#

set -uo pipefail

# ------------------------------ CONFIG --------------------------------
MOUNT_ROOT="/media/usbvideo"
STATE_DIR="/run/usb-video-player"
PLAYLIST="$STATE_DIR/playlist.m3u"
CD_DIR="$STATE_DIR/countdown"
CD_LIST="$STATE_DIR/countdown.m3u"
MSG_IMG="/usr/local/share/usb-video-player/no-media.png"

POLL=2                       # secondi tra un controllo e l'altro
COUNTDOWN=10                 # secondi di countdown prima dell'avvio
VIDEO_EXT="mp4 mkv avi mov m4v mpg mpeg ts m2ts webm wmv flv vob 3gp ogv"

# Uscita fissa su HDMI A (la porta HDMI vicina all'alimentazione sul Pi 5)
DRM_CONNECTOR="HDMI-A-1"
AUDIO_DEVICE="alsa/sysdefault:CARD=vc4hdmi0"

FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
CONSOLE_TTY="/dev/tty1"
# ----------------------------------------------------------------------

MPV_PID=""
STATE="none"          # none | message | countdown | playing
IM=""                 # binario ImageMagick

log() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*"; }

# ---------------------------------------------------------------- setup
resolve_audio_device() {
	# se la scheda HDMI A non esiste con questo nome, lascia decidere a mpv
	if ! aplay -L 2>/dev/null | grep -q 'CARD=vc4hdmi0'; then
		if aplay -L 2>/dev/null | grep -q 'CARD=vc4hdmi'; then
			AUDIO_DEVICE="alsa/sysdefault:CARD=vc4hdmi"
		else
			log "ATTENZIONE: scheda audio HDMI non trovata, uso il default"
			AUDIO_DEVICE=""
		fi
	fi
}

prepare() {
	mkdir -p "$MOUNT_ROOT" "$STATE_DIR" "$CD_DIR"

	command -v magick  >/dev/null 2>&1 && IM=magick
	[ -z "$IM" ] && command -v convert >/dev/null 2>&1 && IM=convert

	# console pulita: niente cursore, niente spegnimento schermo
	if [ -w "$CONSOLE_TTY" ]; then
		setterm --blank 0 --powerdown 0 --cursor off >"$CONSOLE_TTY" 2>/dev/null || true
		printf '\033[2J\033[H\033[?25l' >"$CONSOLE_TTY" 2>/dev/null || true
	fi

	# espressione find con tutte le estensioni
	FIND_EXPR=(\()
	local first=1 e
	for e in $VIDEO_EXT; do
		[ $first -eq 1 ] && first=0 || FIND_EXPR+=(-o)
		FIND_EXPR+=(-iname "*.$e")
	done
	FIND_EXPR+=(\))

	resolve_audio_device

	# opzioni comuni mpv
	MPV_OPTS=(
		--no-config --no-terminal --really-quiet
		--vo=gpu --gpu-context=drm --hwdec=auto-safe
		--drm-connector="$DRM_CONNECTOR"
		--fullscreen --no-osc --osd-level=0 --cursor-autohide=always
		--no-input-default-bindings --input-vo-keyboard=no
	)
	[ -n "$AUDIO_DEVICE" ] && MPV_OPTS+=(--audio-device="$AUDIO_DEVICE")
}

# ------------------------------------------------------------- chiavette
mount_usb() {
	local link dev fstype mp
	shopt -s nullglob
	for link in /dev/disk/by-id/usb-*; do
		dev="$(readlink -f "$link")" || continue
		[ -b "$dev" ] || continue
		findmnt -n -S "$dev" >/dev/null 2>&1 && continue
		fstype="$(blkid -o value -s TYPE "$dev" 2>/dev/null)"
		[ -n "$fstype" ] || continue            # salta i dischi senza filesystem
		case "$fstype" in swap|linux_raid_member) continue ;; esac
		mp="$MOUNT_ROOT/$(basename "$dev")"
		mkdir -p "$mp"
		if mount -o ro,noatime,nosuid,nodev "$dev" "$mp" 2>/dev/null; then
			log "montata $dev ($fstype) su $mp"
		else
			rmdir "$mp" 2>/dev/null
		fi
	done
	shopt -u nullglob
}

cleanup_mounts() {
	local mp dev
	for mp in "$MOUNT_ROOT"/*; do
		[ -d "$mp" ] || continue
		if mountpoint -q "$mp"; then
			dev="$(findmnt -n -o SOURCE --target "$mp" 2>/dev/null)"
			if [ ! -b "$dev" ]; then
				umount -l "$mp" 2>/dev/null && log "rimossa $mp"
				rmdir "$mp" 2>/dev/null
			fi
		else
			rmdir "$mp" 2>/dev/null
		fi
	done
}

# ------------------------------------------------------------- playlist
build_playlist() {
	: >"$PLAYLIST"
	[ -d "$MOUNT_ROOT" ] || return 0
	find "$MOUNT_ROOT" -type f "${FIND_EXPR[@]}" \
		! -name '._*' \
		! -path '*/.Trashes/*' \
		! -path '*/.Spotlight-V100/*' \
		! -path '*/System Volume Information/*' \
		-print 2>/dev/null | LC_ALL=C sort -V >"$PLAYLIST"
}

# ------------------------------------------------------------ countdown
# Genera una PNG per ogni secondo: mpv le riproduce in sequenza a 1s l'una.
build_countdown() {
	local count="$1" i idx riga1 riga2 file
	rm -f "$CD_DIR"/*.png "$CD_LIST"
	[ -n "$IM" ] || return 1

	if [ "$count" -eq 1 ]; then riga1="Trovato 1 video"; else riga1="Trovati $count video"; fi

	for i in $(seq "$COUNTDOWN" -1 1); do
		idx=$(printf '%02d' $((COUNTDOWN - i + 1)))
		file="$CD_DIR/cd_$idx.png"
		if [ "$i" -eq 1 ]; then riga2="Avvio tra 1 secondo"; else riga2="Avvio tra $i secondi"; fi
		"$IM" -size 1280x720 xc:black \
			-font "$FONT" -fill white -gravity center \
			-pointsize 80 -annotate +0-70 "$riga1" \
			-pointsize 46 -annotate +0+50 "$riga2" \
			"$file" 2>/dev/null || return 1
		printf '%s\n' "$file" >>"$CD_LIST"
	done
	return 0
}

# ------------------------------------------------------------- playback
stop_player() {
	if [ -n "$MPV_PID" ] && kill -0 "$MPV_PID" 2>/dev/null; then
		kill "$MPV_PID" 2>/dev/null
		wait "$MPV_PID" 2>/dev/null
	fi
	MPV_PID=""
}

play_countdown() {
	mpv "${MPV_OPTS[@]}" \
		--no-audio \
		--playlist="$CD_LIST" \
		--image-display-duration=1 \
		--keep-open=no --idle=no &
	MPV_PID=$!
	STATE="countdown"
}

play_videos() {
	mpv "${MPV_OPTS[@]}" \
		--playlist="$PLAYLIST" \
		--loop-playlist=inf \
		--keep-open=no \
		--gapless-audio=yes \
		--prefetch-playlist=yes \
		--cache=yes \
		--idle=no &
	MPV_PID=$!
	STATE="playing"
}

play_message() {
	if [ ! -f "$MSG_IMG" ]; then
		log "ATTENZIONE: immagine $MSG_IMG mancante"
		printf '\033[2J\033[H\n\n   INSERIRE UNA CHIAVETTA USB CON VIDEO COMPATIBILI\n' \
			>"$CONSOLE_TTY" 2>/dev/null
		STATE="message"
		return
	fi
	mpv "${MPV_OPTS[@]}" \
		--no-audio \
		--image-display-duration=inf \
		--loop-file=inf \
		"$MSG_IMG" &
	MPV_PID=$!
	STATE="message"
}

# ----------------------------------------------------------------- main
on_exit() {
	stop_player
	local mp
	for mp in "$MOUNT_ROOT"/*; do
		mountpoint -q "$mp" 2>/dev/null && umount -l "$mp" 2>/dev/null
	done
	exit 0
}
trap on_exit INT TERM

prepare
log "avviato (video su $DRM_CONNECTOR, audio su ${AUDIO_DEVICE:-default})"

current_sig="__init__"

while true; do
	mount_usb
	cleanup_mounts
	build_playlist

	count=$(wc -l <"$PLAYLIST")
	sig=$(md5sum "$PLAYLIST" | cut -d' ' -f1)

	if [ "$sig" != "$current_sig" ]; then
		# contenuto cambiato: chiavetta inserita, rimossa o modificata
		stop_player
		if [ "$count" -gt 0 ]; then
			log "trovati $count video"
			if build_countdown "$count"; then
				play_countdown
			else
				log "countdown non disponibile (ImageMagick mancante), avvio diretto"
				play_videos
			fi
		else
			log "nessun video compatibile -> messaggio a schermo"
			play_message
		fi
		current_sig="$sig"

	elif [ -n "$MPV_PID" ] && ! kill -0 "$MPV_PID" 2>/dev/null; then
		# il player è uscito da solo
		MPV_PID=""
		if [ "$STATE" = "countdown" ]; then
			log "countdown finito -> riproduzione in loop"
			play_videos
		else
			log "mpv terminato in modo anomalo, riavvio"
			current_sig="__restart__"
		fi
	fi

	# attesa a piccoli passi: se mpv esce (fine countdown) si reagisce subito
	steps=$(( POLL * 5 ))
	while [ "$steps" -gt 0 ]; do
		sleep 0.2
		steps=$(( steps - 1 ))
		if [ -n "$MPV_PID" ] && ! kill -0 "$MPV_PID" 2>/dev/null; then break; fi
	done
done
