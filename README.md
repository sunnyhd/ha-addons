# Home Assistant Add-ons

Ein Add-on-Repository für Home Assistant. Einmal im Add-on-Store hinterlegt,
erscheinen alle Add-ons daraus dort — mit Update-Benachrichtigungen wie bei
jedem anderen Add-on auch.

**Nicht über HACS.** HACS führt Custom Integrations, Lovelace-Karten und Themes;
Add-ons laufen über den Supervisor und damit über den Add-on-Store. Das ist kein
Umweg, sondern der vorgesehene Weg: der Store hier ist derselbe Mechanismus, mit
dem auch die offiziellen Add-ons kommen.

## Einbinden

> **Nicht über HACS.** Dies sind Home-Assistant-**Add-ons**, keine
> Integrationen, Lovelace-Karten oder Themes — sie werden über den **Add-on-Store**
> des Supervisors eingebunden, nicht über HACS. Auf HAOS/Supervised verfügbar,
> nicht auf Home Assistant Container/Core.

**Einstellungen → Add-ons → Add-on-Store → ⋮ → Repositories**, dann diese URL
eintragen:

```
https://github.com/sunnyhd/ha-addons
```

Das Repository muss dafür öffentlich erreichbar sein — der Supervisor klont es
ohne Anmeldung.

## Enthaltene Add-ons

### Local Audio Zones

Teilt einen mehrkanaligen Audio-Ausgang in unabhängige Stereo-Zonen und spielt
jede als eigenen Sendspin-Player für Music Assistant. Ein achtkanaliges
Interface wird so zu vier Stereo-Zonen — jede mit eigener Lautstärke,
Warteschlange und Gruppenzugehörigkeit — plus einer Zone über alle Ausgänge.

Beim Start liest das Add-on die Kanalmap des über `audio: true` hereingereichten
Ausgangs, legt je Ausgangspaar einen `module-remap-sink` in Home Assistants
PulseAudio an und startet einen `sendspin-cli` je Zone. Alle Player laufen in
einem Container, jeder auf einem eigenen Port (8928 aufwärts) und mit eigener,
stabiler `SENDSPIN_ID`. Ein Watchdog startet abgestürzte Player neu und legt
die Sinks erneut an, falls ein Neustart des Audio-Plugins sie entfernt.

**Konfiguration** (vollständig in der Add-on-Oberfläche, keine Datei auf dem
Host, kein Docker-Zugriff, kein abgeschalteter Schutzmodus):

| Option | Bedeutung |
| --- | --- |
| `server` | Adresse des Music-Assistant-Servers (`host:port`, meist `<ha-ip>:8927`). **Pflicht** — ohne Host-Netz kein mDNS, der Player wählt sich ein. |
| `zones` | Liste je Zone: `name` (Anzeigename in MA) und `output` (Ausgangspaar, z. B. `out_3_4_rear`). Beliebig erweiterbar. |
| `master_sink` | Welcher mehrkanalige Ausgang aufgeteilt wird. Leer = erster mit mehr als zwei Kanälen. |
| `buffer_ms` | Puffer je Player in Millisekunden, gegen Aussetzer auf langsamen Systemen. |
| `log_level` | `debug` … `error`. |

**Getestet mit** einer ESI GIGAPORT eX (USB, 8 Ausgänge). Der Ansatz ist aber
nicht auf dieses Modell festgelegt: das Add-on liest die Kanalmap des Ausgangs
zur Laufzeit, statt ein Gerät fest anzunehmen. Andere mehrkanalige USB-Interfaces
— und grundsätzlich jede Soundkarte, die Home Assistants PulseAudio mit einem
Mehrkanal-Profil erkennt — sollten daher ebenso funktionieren. Real verifiziert
ist bislang nur die GIGAPORT eX; andere Geräte können eine abweichende
Kanalordnung mitbringen (dann greift der Zuordnungs-Schritt aus DOCS.md).
Rückmeldungen zu weiteren Interfaces sind willkommen.

Ausgangs-Zuordnung, geräteabhängige Kanalordnung, USB-Strom bei bus-powered
Interfaces und der Betrieb unter HAOS-in-einer-VM sind in
[`zone_players/DOCS.md`](zone_players/DOCS.md) bzw. im Dokumentations-Tab des
Add-ons beschrieben.

## Wartung

Das Add-on erbt sein Image vom Upstream
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon)
(`FROM …:<tag>`) — daraus kommen der Player (`sendspin-cli`), `pactl` und das
Basis-Image; die Zonen-Logik ist davon unabhängig.

Der Workflow `.github/workflows/upstream-bump.yml` beobachtet den Upstream und
öffnet bei einer neuen Version automatisch einen Pull Request, der `FROM`-Tag
und `version` gemeinsam anhebt (samt Test-Checkliste). Einmalig nötig:
**Settings → Actions → General → „Allow GitHub Actions to create and approve
pull requests"** aktivieren. Details und der manuelle Weg stehen in
[`zone_players/DOCS.md`](zone_players/DOCS.md).

## Stand

Läuft produktiv gegen echte Hardware (ESI GIGAPORT eX, 8 Ausgänge → 4 Stereo-
Zonen + „Alle Zonen") und einen laufenden Supervisor. Zwei Stolpersteine der
Inbetriebnahme sind in `DOCS.md` festgehalten: die geräteabhängige Kanalordnung
und die USB-Stromversorgung bus-powered Interfaces (ein USB-3-Port bzw. aktiver
Hub war nötig).
