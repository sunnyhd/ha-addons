# shellcheck shell=bash
# Kanalpaare eines mehrkanaligen Ausgangs, die Sinks dazu, und ein Player je
# Zone. Geteilt zwischen dem Startdienst und allem, was ihn spaeter pruefen will.

readonly PULSE_SOCKET=/run/audio/pulse.sock
readonly STATE_ROOT=/data/zones
readonly RUN_DIR=/run/zone-players
readonly INSTANCE_ID_FILE=/data/instance-id
readonly BASE_PORT=8928

# Die Paare, aus denen eine Stereo-Zone werden kann, mit dem Namensteil, den der
# Sink davon traegt. Dieselbe Aufstellung wie in zones/make-zones.sh und wie im
# nie veroeffentlichten local_audio-Provider von Music Assistant.
readonly ZONE_PAIRS='front-left:front-right:front
rear-left:rear-right:rear
front-center:lfe:center_sub
side-left:side-right:side'

zone::log() {
    printf '%s\n' "$*" >&2
}

# Alle pactl-Aufrufe gehen an die PulseAudio, die `audio: true` hereinreicht --
# nicht an eine, die dieser Container selbst startet. Er startet keine.
zone::pactl() {
    LC_ALL=C PULSE_SERVER="unix:${PULSE_SOCKET}" timeout 5 pactl "$@" 2> /dev/null
}

# Der Socket erscheint, wenn das Audio-Plugin so weit ist. Ohne ihn ist jede
# weitere Zeile hier sinnlos, also wird gewartet statt gescheitert -- ein
# Add-on, das eine Sekunde vor dem Plugin startet, soll nicht aufgeben.
zone::wait_for_pulse() {
    local i
    for ((i = 0; i < 120; i++)); do
        if [ -S "${PULSE_SOCKET}" ] && zone::pactl info > /dev/null; then
            return 0
        fi
        sleep 1
    done
    zone::log 'PulseAudio ist nach zwei Minuten nicht erreichbar.'
    return 1
}

# Eine Kennung, die diesen Container ueberdauert und ihn von jedem anderen
# unterscheidet. Ein Music-Assistant-Server legt Lautstaerke, Gruppen und
# Pairing je Player-ID ab; leiten zwei Player dieselbe ab, landen die
# Einstellungen beider auf dem, der sich zuletzt verbunden hat. Aus dem
# Hostnamen laesst sie sich nicht bilden -- der ist bei jedem Container neu.
zone::instance_id() {
    if [ ! -s "${INSTANCE_ID_FILE}" ]; then
        mkdir -p "$(dirname "${INSTANCE_ID_FILE}")"
        # /proc/sys/kernel/random/uuid gibt es ueberall, wo dieser Container laeuft.
        cat /proc/sys/kernel/random/uuid | cut -c1-8 > "${INSTANCE_ID_FILE}"
    fi
    cat "${INSTANCE_ID_FILE}"
}

# Die Kanalmap des Sinks "$1", als Komma-Liste. Leer, wenn es ihn nicht gibt.
zone::channel_map() {
    zone::pactl list sinks | awk -v target="$1" '
        /^Sink #/ { name = ""; map = "" }
        /^\tName:/ { name = $2 }
        /^\tChannel Map:/ { map = $3; if (name == target) { print map; exit } }
    '
}

# Der mehrkanalige Ausgang, durch den die Zonen spielen sollen: der erste Sink
# mit mehr als zwei Kanaelen, der keiner unserer eigenen ist. Nur ein Vorschlag
# fuer den Fall, dass die Konfiguration keinen nennt -- eine Maschine mit zwei
# Interfaces soll ihn nicht raten muessen.
zone::detect_master() {
    zone::pactl list sinks short | while IFS=$'\t' read -r _ name module spec _; do
        case ${name} in out_*) continue ;; esac
        case ${module} in *remap*) continue ;; esac
        case ${spec} in
            *' '[3-9]ch* | *[0-9][0-9]ch*) printf '%s\n' "${name}"; return 0 ;;
        esac
    done | head -n 1
}

# Die Zonen, die auf diesem Master moeglich sind, eine je Zeile als
#   <sink-name> <master-kanalpaar>
# Gerechnet wird aus der Kanalmap des Geraets, nicht aus seiner Kanalzahl: die
# Zahl sagt nicht, welche Positionen dahinterstehen, und ein Geraet, das von der
# ueblichen Reihenfolge abweicht, bekaeme sonst eine Zuordnung, die still falsch
# ist. Die Buchsennummern im Namen sind die Position in dieser Map.
zone::available_zones() {
    local map=$1
    local -a position
    local pair left right kind i first second

    IFS=',' read -r -a position <<< "${map}"

    while IFS= read -r pair; do
        [ -n "${pair}" ] || continue
        left=${pair%%:*}
        kind=${pair##*:}
        right=${pair#*:}; right=${right%%:*}

        first=''
        second=''
        for i in "${!position[@]}"; do
            [ "${position[${i}]}" = "${left}" ] && first=$((i + 1))
            [ "${position[${i}]}" = "${right}" ] && second=$((i + 1))
        done
        if [ -n "${first}" ] && [ -n "${second}" ]; then
            printf 'out_%d_%d_%s %s,%s\n' "${first}" "${second}" "${kind}" "${left}" "${right}"
        fi
    done <<< "${ZONE_PAIRS}"

    # Die Zone ueber alle Kanaele zugleich -- was ein AV-Receiver "Multi Channel
    # Stereo" nennt. Erst ab sechs Kanaelen sinnvoll; darunter ist sie dasselbe
    # wie das erste Paar.
    if [ "${#position[@]}" -ge 6 ]; then
        printf 'out_all %s\n' "${map}"
    fi
}

# Legt die Sinks an, die es noch nicht gibt. Idempotent, weil dieselbe Funktion
# den Neustart des Audio-Plugins auffaengt: dort sind alle Sinks verschwunden,
# hier sind sie danach wieder da, ohne dass ein Player etwas merkt ausser einer
# Unterbrechung.
zone::ensure_sinks() {
    local master=$1 map=$2
    local existing sink chanmap count target created=0

    existing=$(zone::pactl list sinks short | cut -f2)

    while read -r sink chanmap; do
        [ -n "${sink}" ] || continue
        if printf '%s\n' "${existing}" | grep -qx "${sink}"; then
            continue
        fi

        count=$(printf '%s' "${chanmap}" | tr ',' '\n' | grep -c .)
        if [ "${count}" -eq 2 ]; then
            # Nach aussen ist jede Stereo-Zone gewoehnliches
            # front-left,front-right, ganz gleich, auf welchen Buchsen sie liegt.
            target='front-left,front-right'
        else
            target=${chanmap}
        fi

        # Der Wert von sink_properties steht in doppelten *und* einfachen
        # Anfuehrungszeichen: ohne die inneren zerlegt PulseAudio eine
        # Beschreibung mit Leerzeichen in zwei Argumente und lehnt die ganze
        # Zeile ab.
        if zone::pactl load-module module-remap-sink \
            "sink_name=${sink}" \
            "sink_properties=device.description='${sink}'" \
            "master=${master}" \
            "master_channel_map=${chanmap}" \
            "channels=${count}" \
            "channel_map=${target}" \
            remix=no > /dev/null; then
            created=$((created + 1))
        else
            zone::log "Sink ${sink} liess sich nicht anlegen."
        fi
    done <<< "$(zone::available_zones "${map}")"

    if [ "${created}" -gt 0 ]; then
        # module-device-restore stellt die zuletzt gesetzte Lautstaerke des
        # Masters wieder her, und die liegt *unter* jeder Zone: ein Master auf
        # 40% daempft alle Zonen um 40%, unsichtbar, denn die Zonenregler stehen
        # weiter auf 100. Geregelt wird in den Zonen.
        zone::pactl set-sink-volume "${master}" 100% > /dev/null
        # Einmal aus und wieder an, nachdem die Kanaele neu zugeteilt sind.
        zone::pactl suspend-sink "${master}" 1 > /dev/null
        zone::pactl suspend-sink "${master}" 0 > /dev/null
        zone::log "${created} Zonen-Sinks angelegt auf ${master}."
    fi
}
