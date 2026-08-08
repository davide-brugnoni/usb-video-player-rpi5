# USB Video Player — Raspberry Pi 5

Player video per installazioni: il Raspberry Pi 5 senza interfaccia grafica
riproduce automaticamente in loop tutti i video contenuti nelle chiavette USB
collegate. Se non c'è nessuna chiavetta, o se non contiene video compatibili,
a schermo compare un messaggio di avviso.

## Contenuto

| File | Destinazione | Cosa fa |
|---|---|---|
| `usb-video-player.sh` | `/usr/local/bin/` | lo script del player |
| `usb-video-player.service` | `/etc/systemd/system/` | avvio automatico al boot |
| `install.sh` | — | installa tutto |
| `uninstall.sh` | — | rimuove tutto |
| `firstboot.sh` | — | opzionale, installazione automatica al primo avvio |

## Requisiti

- Raspberry Pi 5 con Raspberry Pi OS Lite (Bookworm o successivo), 64 bit
- schermo collegato alla porta **HDMI A**, quella vicina all'alimentazione
- **connessione a internet almeno per l'installazione**: mpv e ImageMagick non
  sono presenti in Pi OS Lite e vanno scaricati. Dopo, il Pi può restare offline.

## Installazione dalla scheda SD (senza SSH)

Utile quando non hai modo di trasferire file sul Pi già avviato.

1. Scrivi Raspberry Pi OS Lite (64 bit) con Raspberry Pi Imager. Nelle opzioni
   avanzate (icona ingranaggio) imposta **utente e password**, la **Wi-Fi** e
   attiva **SSH**: la rete serve per l'installazione.
2. A flash finito, riinserisci la scheda: sul computer compare la partizione
   **`bootfs`** (su macOS in `/Volumes/bootfs`, su Windows come unità con
   `config.txt` e `cmdline.txt`).
3. Crea lì dentro una cartella `usb-video-player` e copiaci i file di questo
   progetto.
4. Espelli la scheda, inseriscila nel Pi e accendi.

Poi scegli una delle due strade.

### A) Un comando a mano (più semplice)

Collega una tastiera USB, accedi con l'utente impostato nell'Imager e digita:

```bash
sudo bash /boot/firmware/usb-video-player/install.sh
```

In alternativa, la stessa riga via SSH: `ssh utente@raspberrypi.local`.

### B) Installazione automatica al primo avvio

Sulla partizione `bootfs` c'è già un file **`firstrun.sh`** creato dall'Imager.
Aprilo con un editor di testo semplice (su macOS: `nano`, BBEdit o
TextEdit in modalità solo testo — mai un programma che aggiunge formattazione) e
aggiungi questa riga **subito dopo la prima riga** `#!/bin/bash`:

```bash
bash /boot/firmware/usb-video-player/firstboot.sh
```

Salva, espelli, accendi il Pi. Al primo avvio viene creato un servizio che
aspetta la rete, esegue `install.sh` e si disattiva da solo. Bastano un paio di
minuti: al termine il player parte e mostra il messaggio di avviso.

Se l'installazione fallisce (ad esempio Wi-Fi non connessa) il servizio non si
disattiva e riprova al riavvio successivo. Per controllare:

```bash
journalctl -u usb-video-player-setup
```

Nota: `firstrun.sh` esiste solo se hai usato le opzioni avanzate dell'Imager. Se
non c'è, usa la strada A.


## Cosa fa l'installer

Installa i pacchetti necessari (mpv, exfatprogs, ntfs-3g, imagemagick,
alsa-utils, fonts-dejavu-core), genera l'immagine di avviso, configura il
pulsante di accensione e abilita il servizio. Al termine il player è già in
funzione e riparte a ogni avvio del Pi.

Per rimuovere tutto: `sudo bash uninstall.sh`.

## Funzionamento

1. Ogni 2 secondi lo script cerca chiavette USB e le monta in sola lettura sotto
   `/media/usbvideo`.
2. Cerca i file video e li ordina con `sort -V`, che rispetta sia l'ordine
   alfabetico sia quello numerico naturale (`clip2` prima di `clip10`).
3. Mostra per 10 secondi un countdown con il numero di video trovati.
4. Riproduce tutta la playlist in loop infinito con una sola istanza di mpv,
   quindi senza schermate nere tra un file e l'altro.
5. Se togli la chiavetta torna al messaggio di avviso; se la reinserisci
   ricomincia dal countdown.

Estensioni riconosciute: mp4, mkv, avi, mov, m4v, mpg, mpeg, ts, m2ts, webm,
wmv, flv, vob, 3gp, ogv.

## Configurazione

Le variabili sono in cima a `usb-video-player.sh`:

| Variabile | Default | Note |
|---|---|---|
| `COUNTDOWN` | `10` | secondi di countdown; `0` non è supportato, usa un valore ≥ 1 |
| `POLL` | `2` | intervallo di controllo delle chiavette |
| `DRM_CONNECTOR` | `HDMI-A-1` | uscita video |
| `AUDIO_DEVICE` | `alsa/sysdefault:CARD=vc4hdmi0` | uscita audio |
| `VIDEO_EXT` | vedi sopra | estensioni cercate |

Dopo ogni modifica: `sudo systemctl restart usb-video-player`.

Se l'audio non esce, elenca i dispositivi disponibili con
`mpv --audio-device=help` e correggi `AUDIO_DEVICE`.

## HDMI sempre attivo

Se lo schermo si accende dopo il Pi, l'uscita può restare spenta. Per forzarla,
in `/boot/firmware/cmdline.txt` aggiungi alla riga esistente (è una riga sola):

```
video=HDMI-A-1:1920x1080@60D
```

## Comandi utili

```bash
journalctl -u usb-video-player -f      # log in tempo reale
systemctl status usb-video-player      # stato
sudo systemctl restart usb-video-player
sudo systemctl stop usb-video-player   # ferma ora, riparte al boot
sudo systemctl disable --now usb-video-player   # disattiva del tutto
```

## Spegnimento

Pressione breve del pulsante interno del Pi 5: spegnimento pulito. Una seconda
pressione lo riaccende. Tenerlo premuto a lungo forza lo spegnimento immediato,
da evitare.

Le chiavette sono montate in sola lettura, quindi staccarle a caldo non le
danneggia. Il rischio riguarda solo la microSD di sistema.

## Note sul Raspberry Pi 5

- Non ha decodifica hardware H.264: l'1080p va bene in software, il 4K H.264
  può scattare. Per i 4K conviene HEVC, che è accelerato.
- Video con risoluzione o frame rate diversi tra loro possono causare un
  brevissimo riadattamento al cambio file: per un risultato perfettamente
  continuo conviene esportarli tutti nello stesso formato.
- Il login sulla console tty1 non disturba la riproduzione. Se preferisci
  disattivarlo, decommenta le due righe `Conflicts`/`After` in
  `usb-video-player.service` (l'accesso SSH resta disponibile).
