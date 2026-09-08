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

### Local Audio Zones

Ein Add-on, das alles macht: es findet den mehrkanaligen Ausgang, liest dessen
Kanalmap, legt die Zonen-Sinks selbst an und startet je Zone einen Player —
alle in einem Container, jeder auf seinem eigenen Port.

Die Zonen werden in der Add-on-Konfiguration eingetragen, so viele wie das
Interface Ausgangspaare hat. Keine Datei auf dem Host, kein Docker-Zugriff,
kein abgeschalteter Schutzmodus.

Die vollständige Anleitung samt Optionen, Ausgangs-Zuordnung und Stolpersteinen
(geräteabhängige Kanalordnung, USB-Strom bei bus-powered Interfaces, HAOS in
einer VM) steht in **DOCS.md** bzw. im Dokumentations-Tab des Add-ons.

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
