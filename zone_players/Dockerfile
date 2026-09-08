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
RUN rm -f /etc/s6-overlay/s6-rc.d/user/contents.d/sendspin-cli \
          /etc/s6-overlay/s6-rc.d/user/contents.d/sendspin-init \
          /etc/s6-overlay/s6-rc.d/user/contents.d/avahi \
          /etc/s6-overlay/s6-rc.d/user/contents.d/dbus

COPY rootfs/ /

# Der Container haelt seine Zonen selbst am Leben, statt bei einem gescheiterten
# Player zu enden: eine Zone, deren Ausgang gerade verschwunden ist, soll die
# vier anderen nicht mitnehmen.
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
