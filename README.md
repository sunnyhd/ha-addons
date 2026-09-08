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

## Stand

Die Manifeste sind erzeugt und auf gültiges YAML geprüft, gegen einen laufenden
Supervisor und echte Hardware ist noch nichts davon gelaufen.
