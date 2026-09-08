# sys.tec Home Assistant Add-ons

Ein Add-on-Repository für Home Assistant. Einmal im Add-on-Store hinterlegt,
erscheinen alle Add-ons daraus dort — mit Update-Benachrichtigungen wie bei
jedem anderen Add-on auch.

**Nicht über HACS.** HACS führt Custom Integrations, Lovelace-Karten und Themes;
Add-ons laufen über den Supervisor und damit über den Add-on-Store. Das ist kein
Umweg, sondern der vorgesehene Weg: der Store hier ist derselbe Mechanismus, mit
dem auch die offiziellen Add-ons kommen.

## Einbinden

**Einstellungen → Add-ons → Add-on-Store → ⋮ → Repositories**, dann diese URL
eintragen:

```
https://github.com/sunnyhd/ha-addons
```

Das Repository muss dafür öffentlich erreichbar sein — der Supervisor klont es
ohne Anmeldung.

## Enthaltene Add-ons

### Local Audio Zone 1–5

Je ein Sendspin-Player für Music Assistant, der auf **einen** PulseAudio-Sink
spielt. Mehrere davon teilen ein mehrkanaliges Audio-Interface in unabhängige
Stereo-Zonen auf: ein Player je Ausgangspaar, jeder mit eigener Lautstärke,
eigener Warteschlange und eigener Gruppenzugehörigkeit.

Ein achtkanaliges Interface ergibt vier Stereo-Zonen. Die fünfte Instanz ist für
den Sink gedacht, der auf **alle** Ausgänge zugleich spielt — was ein
AV-Receiver „Multi Channel Stereo" nennt. Sie ist keine andere Art von Add-on,
nur eine weitere Instanz: welcher Sink dahintersteht, entscheidet das Feld
**Audio output**. Wer weniger Zonen braucht, installiert einfach weniger.

Sie laufen das Image von
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon);
nur das Manifest unterscheidet sich. Ein Upstream-Update ist hier ein
Versionsstring, kein Merge.

Warum es sie mehrfach gibt: ein Add-on läuft einmal pro Slug. Vier Zonen
brauchen vier Slugs, und drei Dinge müssen sich je Instanz unterscheiden —
der Slug, der AppArmor-Profilname und `SENDSPIN_ID`. Alles andere ist in der
Oberfläche einstellbar.

#### Vorher: die Zonen-Sinks anlegen

Die Add-ons spielen auf Sinks, die es erst geben muss. Angelegt werden sie
einmalig in `/mnt/data/supervisor/audio/custom.pa` — einem Erweiterungspunkt,
den Home Assistants PulseAudio am Ende ihrer `system.pa` selbst einliest
(`.nofail` / `.include /data/custom.pa`), und der Updates des Audio-Plugins
übersteht.

Die Skripte dafür liegen in
[`sunnyhd/local-audio-addon`](https://github.com/sunnyhd/local-audio-addon),
Branch `esi-gigaport-zones`, Verzeichnis `zones/` — mit der vollständigen
Anleitung in `zones/README.de.md`. Kurzform:

```sh
./make-zones.sh 8 Wohnzimmer Küche Bad Büro > zones.conf
./make-custom-pa.sh <master-sink-name> > custom.pa
```

Die Aufteilung stammt aus dem stillgelegten `local_audio`-Provider von Music
Assistant (`remap_topology.py`) — dieselben Kanalpaare, dasselbe
`module-remap-sink`.

#### Danach: je Instanz drei Felder

| Feld | Wert |
|---|---|
| **Audio output** | `pulse:<sink>` — der Sink dieser Zone |
| **Player name** | Wie die Zone in Music Assistant heißen soll |
| **Music Assistant server** | Adresse des MA-Servers, `<host>:8927` |

**Die Server-Adresse ist Pflicht, nicht optional.** Der Grund steckt im Player:
er lauscht auf dem fest eingebauten Port 8928, und das Add-on-Image reicht
keinen anderen durch — `sendspin-cli` kennt zwar ein `--port` und sieht in
seiner Hilfe ausdrücklich zwei Player auf einem Host damit vor, aber das
run-Skript im Image rendert seine Konfiguration aus einer festen
Schlüsselliste, in der `port` nicht vorkommt.

Im Netzwerk-Namespace des Hosts kann diesen Port nur **eine** Instanz bekommen.
Die übrigen scheitern beim Binden, und ein Player, der mit Fehler endet, stoppt
seinen Container — fünf installierte Zonen wären ein laufender Player und vier
gestoppte Container. Deshalb läuft hier jede Instanz in ihrem eigenen
Netzwerk-Namespace (`host_network: false`) und hat damit ihren eigenen Port
8928.

Der Preis dafür ist mDNS: ohne das Netz des Hosts kann sich ein Player nicht
anbieten und der Server nicht zurückverbinden. Deshalb wählt der Player sich
ein, und dafür muss er wissen, wohin — über diese Verbindung läuft danach
alles. Ohne Server-Adresse wartet er darauf, gefunden zu werden, und nichts
wird ihn finden.

## Stand

Die Manifeste sind erzeugt und auf gültiges YAML geprüft, gegen einen laufenden
Supervisor und echte Hardware ist noch nichts davon gelaufen.
