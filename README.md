# USB Video Player — Raspberry Pi 5

Player video per installazioni e allestimenti su Raspberry Pi 5. Il Pi si avvia
senza interfaccia grafica e riproduce in loop tutti i video contenuti in una
chiavetta USB. Se la chiavetta non c'è, o non contiene file compatibili, a
schermo compare un messaggio di avviso.

Nato per mostre e installazioni dove serve una cosa sola: attacchi la corrente,
infili la chiavetta, parte il video. Nessuna tastiera, nessun telecomando,
nessun menu.

## Caratteristiche

- Riconoscimento automatico delle chiavette USB, inserite anche a Pi già acceso
- Montaggio in **sola lettura**: staccare la chiavetta a caldo non la danneggia
- Ordinamento naturale dei file, sia alfabetico che numerico (`clip2` prima di `clip10`)
- Countdown di 10 secondi con il numero di video trovati prima dell'avvio
- Riproduzione in loop infinito con una sola istanza di mpv, senza schermate nere fra un file e l'altro
- Video e audio forzati sull'uscita **HDMI A**
- Messaggio a schermo quando manca la chiavetta o non ci sono video
- Avvio automatico al boot e riavvio automatico in caso di crash
- Spegnimento pulito con il pulsante integrato del Pi 5

## Requisiti

- Raspberry Pi 5
- Raspberry Pi OS Lite 64 bit (Bookworm o successivo)
- microSD da 16 GB o superiore
- schermo collegato alla porta HDMI A, quella vicina all'alimentazione
- connessione a internet **solo durante l'installazione**: mpv e ImageMagick non
  sono presenti in Pi OS Lite. Dopo, il Pi può restare offline per sempre.

## Struttura

```
usb-video-player.sh         lo script del player          -> /usr/local/bin/
usb-video-player.service    unit systemd, avvio al boot   -> /etc/systemd/system/
install.sh                  installazione
uninstall.sh                rimozione
firstboot.sh                installazione automatica al primo avvio (opzionale)
```

## Installazione

Se hai già accesso al Pi via SSH, copia i file in una cartella qualsiasi e lancia:

```bash
sudo bash install.sh
```

L'installer scarica i pacchetti necessari (mpv, exfatprogs, ntfs-3g, imagemagick,
alsa-utils, fonts-dejavu-core), genera l'immagine di avviso, configura il
pulsante di accensione e abilita il servizio. Al termine il player è già in
funzione.

### Installazione dalla scheda SD, senza SSH

Utile quando il Pi non è ancora raggiungibile.

1. Scrivi Raspberry Pi OS Lite 64 bit con Raspberry Pi Imager. Nelle opzioni
   avanzate imposta **utente e password**; l'SSH è consigliato ma facoltativo.
   Con cavo ethernet la rete funziona da sola via DHCP e la Wi-Fi non serve.
2. A flash finito reinserisci la scheda nel computer: compare la partizione
   **`bootfs`**, l'unica leggibile da macOS e Windows.
3. Crea al suo interno una cartella `usb-video-player` e copiaci i file del
   progetto.
4. Espelli la scheda, inseriscila nel Pi e accendi.
5. Con tastiera o via SSH, un comando solo:

```bash
sudo bash /boot/firmware/usb-video-player/install.sh
```

### Installazione completamente automatica

Per saltare anche quell'unico comando: sulla partizione `bootfs` c'è il file
`firstrun.sh` generato dall'Imager. Aprilo con un editor di testo puro e
aggiungi questa riga **subito dopo** `#!/bin/bash`:

```bash
bash /boot/firmware/usb-video-player/firstboot.sh
```

Al primo avvio viene creato un servizio one-shot che attende la rete, esegue
`install.sh` e si disattiva da solo. Se qualcosa va storto il servizio non si
disattiva e riprova al riavvio successivo; il motivo si legge con
`journalctl -u usb-video-player-setup`.

`firstboot.sh` non installa direttamente perché al momento in cui gira
`firstrun.sh` la rete non è ancora attiva e `apt` fallirebbe.

> Il `firstrun.sh` va modificato con un editor di puro testo. Caratteri di
> formattazione o fine riga in stile Windows possono impedire il completamento
> del primo avvio.

## Funzionamento

Ogni due secondi lo script cerca le chiavette USB collegate e le monta in sola
lettura sotto `/media/usbvideo`. Costruisce poi la lista dei file video
ordinandoli con `sort -V`, mostra il countdown e passa l'intera playlist a una
singola istanza di mpv con `--loop-playlist=inf`: essendo un solo processo, il
passaggio da un file all'altro non produce interruzioni.

Se la chiavetta viene rimossa la playlist si svuota e torna il messaggio di
avviso; se viene reinserita si riparte dal countdown.

Estensioni riconosciute: mp4, mkv, avi, mov, m4v, mpg, mpeg, ts, m2ts, webm,
wmv, flv, vob, 3gp, ogv.

## Configurazione

Le variabili sono in cima a `usb-video-player.sh`.

| Variabile | Default | Descrizione |
|---|---|---|
| `COUNTDOWN` | `10` | secondi di countdown (minimo 1) |
| `POLL` | `2` | intervallo di controllo delle chiavette |
| `DRM_CONNECTOR` | `HDMI-A-1` | uscita video |
| `AUDIO_DEVICE` | `alsa/sysdefault:CARD=vc4hdmi0` | uscita audio |
| `VIDEO_EXT` | vedi sopra | estensioni cercate |
| `MOUNT_ROOT` | `/media/usbvideo` | punto di montaggio |

Dopo ogni modifica:

```bash
sudo systemctl restart usb-video-player
```

## Comandi utili

```bash
journalctl -u usb-video-player -f              # log in tempo reale
systemctl status usb-video-player              # stato del servizio
sudo systemctl restart usb-video-player        # riavvia
sudo systemctl stop usb-video-player           # ferma, riparte al boot
sudo systemctl disable --now usb-video-player  # disattiva del tutto
```

## Spegnimento

Una pressione breve del pulsante integrato del Pi 5 avvia uno spegnimento
pulito; una seconda pressione riaccende. Tenerlo premuto a lungo forza lo
spegnimento immediato, da evitare.

L'installer scrive un drop-in in `/etc/systemd/logind.conf.d/` che rende questo
comportamento esplicito. Per disabilitare il pulsante — utile se il Pi è
accessibile al pubblico — sostituisci `poweroff` con `ignore` in quel file.

## Risoluzione problemi

**Schermo nero all'accensione.** Se lo schermo si accende dopo il Pi, l'uscita
può restare spenta. Aggiungi alla riga esistente di `/boot/firmware/cmdline.txt`
(è una riga sola):

```
video=HDMI-A-1:1920x1080@60D
```

**Nessun audio.** Elenca i dispositivi disponibili e correggi `AUDIO_DEVICE`:

```bash
mpv --audio-device=help
```

**Video a scatti.** Il Pi 5 non ha decodifica hardware H.264. L'1080p viene
gestito in software senza problemi, il 4K H.264 può scattare: per i 4K conviene
esportare in HEVC, che è accelerato.

**Micro-interruzioni al cambio file.** Succede quando i video hanno risoluzione
o frame rate diversi fra loro. Per un risultato perfettamente continuo esportali
tutti nello stesso formato.

**La chiavetta non viene letta.** Verifica il filesystem: exFAT, FAT32, NTFS ed
ext4 sono supportati. Il formato APFS del Mac no.

## Rimozione

```bash
sudo bash uninstall.sh
```

Rimuove servizio, script e configurazione. I pacchetti installati restano sul
sistema.

## Licenza

MIT.
