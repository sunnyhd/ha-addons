# shellcheck shell=bash
# Channel pairs of a multi-channel output, the sinks for them, and one player per
# zone. Shared between the startup service and anything that later inspects it.

readonly PULSE_SOCKET=/run/audio/pulse.sock
readonly STATE_ROOT=/data/zones
readonly RUN_DIR=/run/zone-players
readonly INSTANCE_ID_FILE=/data/instance-id
readonly BASE_PORT=8928

# The pairs a stereo zone can be made from, with the name part its sink carries.
# The same set as in zones/make-zones.sh and as in the never-released local_audio
# provider of Music Assistant.
readonly ZONE_PAIRS='front-left:front-right:front
rear-left:rear-right:rear
front-center:lfe:center_sub
side-left:side-right:side'

zone::log() {
    printf '%s\n' "$*" >&2
}

# Every pactl call goes to the PulseAudio that `audio: true` maps in -- not to
# one this container starts itself. It starts none.
zone::pactl() {
    LC_ALL=C PULSE_SERVER="unix:${PULSE_SOCKET}" timeout 5 pactl "$@" 2> /dev/null
}

# The socket appears once the audio plugin is ready. Without it every further
# line here is pointless, so we wait rather than fail -- an add-on that starts a
# second before the plugin should not give up.
zone::wait_for_pulse() {
    local i
    for ((i = 0; i < 120; i++)); do
        if [ -S "${PULSE_SOCKET}" ] && zone::pactl info > /dev/null; then
            return 0
        fi
        sleep 1
    done
    zone::log 'PulseAudio is not reachable after two minutes.'
    return 1
}

# An identifier that outlives this container and tells it apart from any other.
# A Music Assistant server files volume, groups and pairing per player id; if two
# players derive the same one, both their settings land on whichever connected
# last. It cannot be formed from the hostname -- that is new for every container.
zone::instance_id() {
    if [ ! -s "${INSTANCE_ID_FILE}" ]; then
        mkdir -p "$(dirname "${INSTANCE_ID_FILE}")"
        # /proc/sys/kernel/random/uuid exists everywhere this container runs.
        cat /proc/sys/kernel/random/uuid | cut -c1-8 > "${INSTANCE_ID_FILE}"
    fi
    cat "${INSTANCE_ID_FILE}"
}

# The channel map of sink "$1", as a comma list. Empty if it does not exist.
zone::channel_map() {
    zone::pactl list sinks | awk -v target="$1" '
        /^Sink #/ { name = ""; map = "" }
        /^\tName:/ { name = $2 }
        /^\tChannel Map:/ { map = $3; if (name == target) { print map; exit } }
    '
}

# The multi-channel output the zones should play through: the first sink with
# more than two channels that is not one of our own. Only a suggestion for the
# case where the configuration names none -- a machine with two interfaces should
# not have to guess it.
zone::detect_master() {
    zone::pactl list sinks short | while IFS=$'\t' read -r _ name module spec _; do
        case ${name} in out_*) continue ;; esac
        case ${module} in *remap*) continue ;; esac
        case ${spec} in
            *' '[3-9]ch* | *[0-9][0-9]ch*) printf '%s\n' "${name}"; return 0 ;;
        esac
    done | head -n 1
}

# The zones possible on this master, one per line as
#   <sink-name> <master-channel-pair>
# Computed from the device's channel map, not from its channel count: the count
# does not say which positions are behind it, and a device that deviates from the
# usual order would otherwise get a mapping that is silently wrong. The socket
# numbers in the name are the position in this map.
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

    # The zone over all channels at once -- what an AV receiver calls "Multi
    # Channel Stereo". Only meaningful from six channels up; below that it is the
    # same as the first pair.
    if [ "${#position[@]}" -ge 6 ]; then
        printf 'out_all %s\n' "${map}"
    fi
}

# Creates the sinks that do not exist yet. Idempotent, because the same function
# catches a restart of the audio plugin: there all sinks are gone, here they are
# back afterwards, without a player noticing anything but an interruption.
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
            # To the outside every stereo zone is ordinary front-left,front-right,
            # no matter which sockets it sits on.
            target='front-left,front-right'
        else
            target=${chanmap}
        fi

        # The sink_properties value is in double *and* single quotes: without the
        # inner ones PulseAudio splits a description containing a space into two
        # arguments and rejects the whole line.
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
            zone::log "Could not create sink ${sink}."
        fi
    done <<< "$(zone::available_zones "${map}")"

    if [ "${created}" -gt 0 ]; then
        # module-device-restore restores the master's last-set volume, and that
        # sits *underneath* every zone: a master at 40% attenuates all zones by
        # 40%, invisibly, since the zone faders still read 100. Regulation happens
        # in the zones.
        zone::pactl set-sink-volume "${master}" 100% > /dev/null
        # Off and on again, after the channels have been reassigned.
        zone::pactl suspend-sink "${master}" 1 > /dev/null
        zone::pactl suspend-sink "${master}" 0 > /dev/null
        zone::log "Created ${created} zone sinks on ${master}."
    fi
}
