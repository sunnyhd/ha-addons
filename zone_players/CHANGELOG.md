# Changelog

## 0.1.0

Erste Version.

- Teilt einen mehrkanaligen Ausgang in unabhaengige Stereo-Zonen und spielt
  jede als eigener Sendspin-Player fuer Music Assistant -- alle Player in einem
  Container, jeder auf seinem eigenen Port (8928 aufwaerts).
- Legt die `module-remap-sink`-Sinks beim Start selbst an, liest dazu die
  Kanalmap des Ausgangs und rechnet daraus die moeglichen Paare. Ein Watchdog
  startet einen beendeten Player neu und legt die Sinks wieder an, falls ein
  Neustart des Audio-Plugins sie mitnimmt.
- Zonen werden in den Add-on-Optionen eingetragen; Sink, Anzeigename und Server
  je Zone. Kein manuelles Editieren von Dateien auf dem Host.
- Setzt den Master-Sink auf 100 % und suspendiert/reaktiviert ihn nach dem
  Anlegen der Zonen -- gegen eine von `module-device-restore` gespeicherte
  Lautstaerke, die sonst unsichtbar unter jeder Zone daempft.
