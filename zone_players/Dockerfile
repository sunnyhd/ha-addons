# Inherits from the published Local Audio image: sendspin-cli, pactl, s6-overlay
# and the output-backend libraries are already built into it. All this add-on
# adds is the mode of operation -- one process per zone instead of a single
# player.
#
# No ARG BUILD_FROM: the Supervisor sets that to the architecture's Home
# Assistant base image, which has no player in it. The tag is therefore written
# out. It is the version of the upstream *image* -- separate from this add-on's
# own version in config.yaml, which has its own line. The upstream-bump workflow
# raises both: this tag to the new image release, the add-on version by a patch.
# The manifest is multi-arch, so `docker build` pulls the matching variant.
FROM ghcr.io/music-assistant/local-audio-addon:0.1.13

# Disable the base image's four services. sendspin-cli starts exactly one player
# -- not the plan here. sendspin-init decides on the bundled daemons and fails
# the container without a reachable Supervisor; avahi and dbus advertise a player
# over mDNS, which reaches nobody without host networking anyway. The files stay
# in place, they are just no longer activated.
#
# Each file is checked before removal instead of a blind `rm -f`. If the base
# image renames one of these services on a version bump, or restructures the s6
# chain, a blind rm would no-op -- the renamed service would then start BESIDE
# ours and bring back the port-8928 fight (or avahi on 5353) silently. As an
# assertion this becomes a red build instead of a silent failure in operation.
RUN set -eu; \
    for svc in sendspin-cli sendspin-init avahi dbus; do \
        f="/etc/s6-overlay/s6-rc.d/user/contents.d/${svc}"; \
        if [ ! -e "${f}" ]; then \
            echo "ERROR: expected s6 service missing: ${f}" >&2; \
            echo "The base image was restructured -- review the Dockerfile before raising the tag." >&2; \
            exit 1; \
        fi; \
        rm -f "${f}"; \
    done

COPY rootfs/ /

# The container keeps its zones alive itself instead of ending when one player
# fails: a zone whose output has just disappeared should not take the other four
# down with it.
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
