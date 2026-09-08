# Erbt vom veroeffentlichten Local-Audio-Image: sendspin-cli, pactl, s6-overlay
# und die Bibliotheken der Ausgabe-Backends sind darin schon fertig gebaut. Was
# dieses Add-on hinzufuegt, ist ausschliesslich die Betriebsart -- ein Prozess
# je Zone statt einem einzigen Player.
#
# Kein ARG BUILD_FROM: das setzt der Supervisor auf das Home-Assistant-Basisimage
# der Architektur, und darin gibt es keinen Player. Der Tag steht deshalb
# ausgeschrieben; er wird beim Anheben von `version` in config.yaml mitgezogen.
# Das Manifest ist multi-arch, `docker build` zieht also die passende Variante.
FROM ghcr.io/music-assistant/local-audio-addon:0.1.13

# Die vier Dienste des Basisimages abschalten. sendspin-cli startet genau einen
# Player -- das ist hier nicht der Plan. sendspin-init entscheidet ueber die
# gebuendelten Daemons und laesst den Container ohne erreichbaren Supervisor
# fehlschlagen; avahi und dbus tragen einen Player ueber mDNS an, was ohne das
# Netz des Hosts ohnehin niemanden erreicht. Die Dateien bleiben liegen, nur
# aktiviert sind sie nicht mehr.
#
# Jede Datei wird vor dem Loeschen geprueft, statt blind `rm -f`. Benennt das
# Basisimage bei einem Versions-Bump einen dieser Dienste um oder strukturiert
# die s6-Kette um, liefe ein blindes rm ins Leere -- der umbenannte Dienst
# startete dann NEBEN unserem, und der Port-8928-Streit (bzw. avahi auf 5353)
# kaeme still zurueck. Als Assertion wird daraus ein roter Build statt eines
# stillen Ausfalls im Betrieb.
RUN set -eu; \
    for svc in sendspin-cli sendspin-init avahi dbus; do \
        f="/etc/s6-overlay/s6-rc.d/user/contents.d/${svc}"; \
        if [ ! -e "${f}" ]; then \
            echo "FEHLER: erwarteter s6-Dienst fehlt: ${f}" >&2; \
            echo "Das Basisimage wurde umstrukturiert -- Dockerfile pruefen, bevor der Tag angehoben wird." >&2; \
            exit 1; \
        fi; \
        rm -f "${f}"; \
    done

COPY rootfs/ /

# Der Container haelt seine Zonen selbst am Leben, statt bei einem gescheiterten
# Player zu enden: eine Zone, deren Ausgang gerade verschwunden ist, soll die
# vier anderen nicht mitnehmen.
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
