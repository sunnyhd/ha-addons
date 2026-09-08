# Local Audio Zones

Teilt einen mehrkanaligen Audio-Ausgang in unabhaengige Stereo-Zonen und spielt
jede als eigenen Sendspin-Player fuer Music Assistant. Ein achtkanaliges
USB-Interface wird so zu vier Stereo-Zonen -- ein Player je Ausgangspaar, jeder
mit eigener Lautstaerke, Warteschlange und Gruppenzugehoerigkeit -- plus einer
Zone, die auf alle Ausgaenge zugleich spielt.

## Einrichtung

1. **Interface anschliessen und Profil setzen.** Auf der Home-Assistant-Konsole:

   ```sh
   ha audio info
   ha audio profile --card <kartenname> --name output:analog-surround-71
   ha audio restart
   ```

   Ein Geraet auf `analog-stereo` hat zwei Kanaele und nichts aufzuteilen.

2. **Add-on installieren**, **Music Assistant server** auf `<ha-ip>:8927`
   setzen, und je genutztem Ausgangspaar eine Zone eintragen (Name + Ausgang).

3. **Starten.** Das Log nennt den gefundenen Ausgang, seine Kanalmap und jede
   gestartete Zone.

Kein Eingriff auf dem Host, kein Docker-Zugriff, kein abgeschalteter
Schutzmodus -- das Add-on legt die Sinks selbst ueber die PulseAudio an, die
Home Assistant hereinreicht.

## Optionen

| Option | Bedeutung |
| --- | --- |
| **Music Assistant server** | Adresse des MA-Servers, `host:port` (meist `<ha-ip>:8927`). **Pflicht**: jede Zone laeuft im eigenen Netzwerk-Namespace, kann sich also nicht ueber mDNS anbieten und waehlt sich beim Server ein. |
| **Zones** | Eine Zeile je Zone: `name` (so heisst der Player in MA) und `output` (das Ausgangspaar). |
| **Master sink** | Welcher mehrkanalige Ausgang aufgeteilt wird. Leer = automatisch der erste mit mehr als zwei Kanaelen. |
| **Audio buffer** | Wie viel Audio jeder Player puffert (ms). Hochsetzen, wo der Ton abreisst. |

## Welcher Ausgang ist welcher

| Zonen-Ausgang | Buchsen | Kanalpositionen |
| --- | --- | --- |
| `out_1_2_front` | 1 / 2 | front-left, front-right |
| `out_3_4_rear` | 3 / 4 | rear-left, rear-right |
| `out_5_6_center_sub` | 5 / 6 | front-center, lfe |
| `out_7_8_side` | 7 / 8 | side-left, side-right |
| `out_all` | alle | die volle Kanalmap |

Die Namen sind PulseAudio-Kanalpositionen, keine Aussage darueber, was
angeschlossen ist -- `out_5_6_center_sub` ist ein Etikett fuer zwei Buchsen,
kein Subwoofer.

## Wichtig: geraeteabhaengige Kanalordnung

Manche Interfaces melden ihre acht Kanaele **nicht** in der Standard-7.1-Ordnung.
Die ESI GIGAPORT eX etwa hat die Reihenfolge

```
FL FR FC LFE RL RR FLC FRC
```

waehrend PulseAudio `FL FR RL RR FC LFE SL SR` annimmt. Dadurch landen zwei
Zonen auf vertauschten Buchsen (bei der GIGAPORT eX: das rear-Paar auf 5/6, das
center/lfe-Paar auf 3/4). Der Effekt ist rein die Zuordnung -- der Ton kommt
sauber, nur aus dem falschen Paar.

**So prueft und korrigiert man das:** Eine Zone nach der anderen abspielen und
sehen/hoeren, aus welchem Ausgang sie kommt. Landet eine Zone falsch, in den
Optionen die beiden betroffenen `output`-Werte tauschen. Beispiel GIGAPORT eX:

| Raum | soll Buchse | `output` |
| --- | --- | --- |
| Kueche | 3 / 4 | `out_5_6_center_sub` |
| Bad | 5 / 6 | `out_3_4_rear` |

## Stolpersteine aus der Praxis

- **Bus-powered Interface an schwachem USB-Port.** Ein bus-versorgtes Interface
  kann am USB genug Strom fuer den Digitalteil bekommen (Enumeration,
  Power-LED), aber zu wenig fuer die analoge Ausgangsstufe -- dann sind die
  Ausgaenge stumm und die Signal-LEDs bleiben aus, **ohne** dass der Kernel
  einen Fehler meldet. Abhilfe: ein **USB-3-Port** (liefert mehr Strom) oder ein
  aktiver USB-Hub. Bei der GIGAPORT eX war genau das die Ursache stummer
  Ausgaenge.

- **HAOS als VM mit USB-Passthrough.** USB-Audio ist isochron und reagiert
  empfindlich auf Virtualisierung. Passthrough des **ganzen PCI-USB-Controllers**
  ist deutlich zuverlaessiger als das Durchreichen eines einzelnen USB-Geraets.
  Kommt der Ton auf Bare-Metal (Laptop) aber nicht in der VM, ist das der
  Verdacht.

- **Kein Ton, aber Signal-LEDs pruefen zuerst.** Die 8 Signal-LEDs zeigen
  anliegendes Audio je Kanal. Leuchten sie, kommt das Signal an -- auch wenn
  keine Lautsprecher angeschlossen sind. Erst die LEDs, dann die Kette dahinter.

## Wie es funktioniert

Ein Add-on laeuft einmal pro Slug, und der Player lauscht auf einem festen Port
(8928). Fuenf Container im Netz des Hosts koennten sich nur um denselben Port
streiten -- in **einem** Container ist es eine Zaehlung: `sendspin-cli` nimmt ein
`--port`, und seine Hilfe nennt genau zwei Player auf einem Host als den Fall
dafuer. Deshalb laufen alle Zonen hier in einem Container, jede auf ihrem
eigenen Port.

Jede Zone bekommt eine eigene, stabile `SENDSPIN_ID` (aus einer einmalig in
`/data` erzeugten Kennung). Ohne die wuerden alle dieselbe aus der MAC ableiten,
und ein Server legt Lautstaerke, Gruppen und Pairing je ID ab -- die
Einstellungen aller Zonen landeten sonst auf der zuletzt verbundenen.

Das Add-on nutzt das Image von
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon),
mit seinem eigenen Dienst an Stelle des Einzel-Player-Dienstes.

## Wartung / Aktualisierung

Dieses Add-on erbt sein Image vom Upstream
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon)
(`FROM ghcr.io/music-assistant/local-audio-addon:<tag>` im Dockerfile). Daraus
kommen `sendspin-cli`, `pactl`, s6-overlay und das sicherheitsgepruefte
Basis-Image. Die Zonen-Logik dieses Add-ons ist davon unabhaengig.

**Automatisch:** Der Workflow `.github/workflows/upstream-bump.yml` prueft
woechentlich (und auf Knopfdruck) den neuesten Upstream-Release und oeffnet bei
einer neuen Version einen Pull Request, der den `FROM`-Tag **und** `version` in
config.yaml gemeinsam anhebt und einen CHANGELOG-Eintrag mit Test-Checkliste
ergaenzt. Damit der Workflow PRs oeffnen darf, muss in den Repo-Einstellungen
einmalig **Settings → Actions → General → "Allow GitHub Actions to create and
approve pull requests"** aktiviert sein.

**Manuell (Rueckfallebene):**

```sh
# neuesten Upstream-Tag ermitteln
gh api repos/music-assistant/local-audio-addon/releases/latest --jq .tag_name
# im Dockerfile FROM ...:<neu> und in config.yaml version: "<neu>" setzen (gleich halten)
```

**Nach jedem Bump testen** -- ein Bump ist nicht fertig, bevor das steht:

1. Add-on **rebuild** laeuft durch. Die Assertion im Dockerfile faengt eine
   Umstrukturierung der s6-Dienste im Basis-Image als **roten Build** ab, statt
   sie still durchzulassen (ein umbenannter Dienst wuerde sonst neben unserem
   starten und den Port-8928-Streit zurueckbringen).
2. `docker exec hassio_audio pactl list sinks short` zeigt die Zonen-Sinks
   (`out_*`).
3. Das Add-on-Log zeigt einen `handshake complete` je Zone.
4. Ein Testton je Zone kommt auf dem erwarteten Ausgang.

Multichannel ist laut Upstream bewusst *ausserhalb* des Music-Assistant-Cores
(PR music-assistant/server#5132 wurde "Addressed outside Music Assistant Core"
geschlossen). Dieses Community-Add-on ist damit der vorgesehene Ort fuer die
Zonen-Aufteilung; der Upstream bleibt der Einzel-Player.
