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

- Raspberry Pi 5 con alimentatore USB-C PD da **27 W (5 V/5 A)**: con alimentatori
  meno potenti le porte USB vengono limitate e le chiavette possono non essere lette
- Raspberry Pi OS Lite 64 bit
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
```

## Installazione

Prepara la scheda con Raspberry Pi Imager: scegli Raspberry Pi OS Lite 64 bit e
nelle opzioni di personalizzazione imposta utente, password e SSH. Con cavo
ethernet la rete funziona da sola via DHCP.

Avvia il Pi, collegati via SSH e lancia:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/davide-brugnoni/usb-video-player-rpi5.git
cd usb-video-player-rpi5
sudo bash install.sh
```

L'installer scarica i pacchetti necessari (mpv, exfatprogs, ntfs-3g, imagemagick,
alsa-utils, fonts-dejavu-core), genera l'immagine di avviso, configura il
pulsante di accensione e abilita il servizio. Al termine il player è già in
funzione: sullo schermo compare il messaggio di avviso, e inserendo una chiavetta
partono i video.

Per aggiornare a una versione successiva:

```bash
cd usb-video-player-rpi5
git pull
sudo bash install.sh
```

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

Le modifiche vanno fatte sul file installato e poi applicate:

```bash
sudo nano /usr/local/bin/usb-video-player.sh
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

Il servizio occupa la console tty1, quindi il login locale da tastiera non è
disponibile: si lavora via SSH. Fermando il servizio il prompt torna.

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

**L'immagine lampeggia a intervalli regolari.** È il prompt di login sulla
console che si contende lo schermo con il player. La unit contiene
`Conflicts=getty@tty1.service` per evitarlo: se hai una versione precedente,
aggiorna e ricarica con `sudo systemctl daemon-reload`.

**Undervoltage detected nel log.** L'alimentatore non è adeguato: serve un
caricatore USB-C PD da 27 W. Con uno meno potente le porte USB vengono limitate
e le chiavette possono non essere riconosciute.

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

[MIT](LICENSE) — Davide Brugnoni
