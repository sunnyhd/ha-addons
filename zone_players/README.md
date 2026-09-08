# Local Audio Zones

Splits one multi-channel audio output into independent stereo zones, and plays
each as its own Sendspin player for Music Assistant.

An eight-channel USB interface becomes four zones — one per pair of outputs,
each with its own volume, queue and group membership — plus one that plays to
every output at once.

## Setup

1. Plug the interface in and set its profile to the widest one it offers, on
   the Home Assistant console:

   ```sh
   ha audio info                       # find the card name
   ha audio profile --card <card> --name output:analog-surround-71
   ha audio restart
   ```

   A device left on `analog-stereo` has two channels and nothing to split.

2. Install this add-on, set **Music Assistant server** to `<your-ha-ip>:8927`,
   and add one zone per pair of outputs you use.

3. Start it. The log names the output it found, its channel map, and every zone
   it started.

Nothing else is needed — no file on the host, no Docker access, no protection
mode. The add-on creates the sinks itself through the PulseAudio that Home
Assistant maps in.

## Which output is which

| Zone output | Interface outputs | Channel positions |
| --- | --- | --- |
| `out_1_2_front` | 1 and 2 | front-left, front-right |
| `out_3_4_rear` | 3 and 4 | rear-left, rear-right |
| `out_5_6_center_sub` | 5 and 6 | front-center, lfe |
| `out_7_8_side` | 7 and 8 | side-left, side-right |
| `out_all` | all of them | the full channel map |

The names are PulseAudio channel positions, not a claim about what is plugged
in — `out_5_6_center_sub` is a label for two sockets, not a subwoofer. The
numbers are positions in the device's own channel map, which the add-on reads
rather than assumes: a device with four channels offers the first two entries,
and one that orders its channels differently gets a different mapping.

A zone set to an output the device does not have stops the add-on with a line
naming what it does have, rather than playing somewhere unexpected.

## What it does at startup

- finds the multi-channel output (or uses **Master sink** if set) and reads its
  channel map
- creates one `module-remap-sink` per configured pair, if it is not there yet
- pins the master sink to 100% — `module-device-restore` can otherwise put a
  saved volume *underneath* every zone, which attenuates all of them invisibly
- starts one `sendspin-cli` per zone, each on its own port, with its own
  identity and state

It keeps both alive: a player that exits is restarted rather than taking the
other zones down with it, and the sinks are recreated if a restart of Home
Assistant's audio plugin removes them.

## Notes

Each player needs a stable identity of its own — a server files volume, group
membership and pairing under it. The add-on derives one per zone from an id it
generates once and keeps in `/data`, so the zones stay distinct across restarts
and do not collide with any other machine.

This add-on runs the image published by
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon),
with its own service in place of the single-player one.
