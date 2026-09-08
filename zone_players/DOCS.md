# Local Audio Zones

Splits one multi-channel audio output into independent stereo zones and plays
each as its own Sendspin player for Music Assistant. An eight-channel USB
interface becomes four stereo zones -- one player per output pair, each with its
own volume, queue and group membership -- plus one zone that plays to every
output at once.

> Home Assistant renamed **Add-ons** to **Apps** in the UI. This page uses
> "app" for the installed thing and UI actions, and keeps "add-on" only for the
> packaging concept (the add-on repository, the `config.yaml` manifest).

## Setup

1. **Plug the interface in and set the profile.** On the Home Assistant console:

   ```sh
   ha audio info
   ha audio profile --card <card-name> --name output:analog-surround-71
   ha audio restart
   ```

   A device on `analog-stereo` has two channels and nothing to split.

2. **Install the app** (Settings → Apps → this repository → *Local Audio Zones*
   → Install), set **Music Assistant server** to `<ha-ip>:8927`, and add one zone
   per output pair you use (name + output).

3. **Start it.** The log names the output it found, its channel map and every
   zone it started.

No change on the host, no Docker access, no disabled protection mode -- the
app creates the sinks itself through the PulseAudio that Home Assistant maps
in.

## Options

| Option | Meaning |
| --- | --- |
| **Music Assistant server** | Address of the MA server, `host:port` (usually `<ha-ip>:8927`). **Required**: each zone runs in its own network namespace, so it cannot advertise over mDNS and dials out to the server instead. |
| **Zones** | One entry per zone: `name` (the player's name in MA) and `output` (the output pair). |
| **Master sink** | Which multi-channel output to split. Empty = automatically the first one with more than two channels. |
| **Audio buffer** | How much audio each player buffers (ms). Raise it where the sound breaks up. |

## Which output is which

| Zone output | Sockets | Channel positions |
| --- | --- | --- |
| `out_1_2_front` | 1 / 2 | front-left, front-right |
| `out_3_4_rear` | 3 / 4 | rear-left, rear-right |
| `out_5_6_center_sub` | 5 / 6 | front-center, lfe |
| `out_7_8_side` | 7 / 8 | side-left, side-right |
| `out_all` | all | the full channel map |

The names are PulseAudio channel positions, not a claim about what is connected
-- `out_5_6_center_sub` is a label for two sockets, not a subwoofer.

## Important: device-dependent channel order

Some interfaces report their eight channels **not** in the standard 7.1 order.
The ESI GIGAPORT eX, for instance, uses the order

```
FL FR FC LFE RL RR FLC FRC
```

while PulseAudio assumes `FL FR RL RR FC LFE SL SR`. As a result two zones end
up on swapped sockets (on the GIGAPORT eX: the rear pair on 5/6, the center/lfe
pair on 3/4). The effect is purely the mapping -- the sound is clean, just out
of the wrong pair.

**How to check and fix it:** play one zone at a time and see/hear which output
it comes from. If a zone is wrong, swap the two affected `output` values in the
options. GIGAPORT eX example:

| Room | should be socket | `output` |
| --- | --- | --- |
| Kitchen | 3 / 4 | `out_5_6_center_sub` |
| Bathroom | 5 / 6 | `out_3_4_rear` |

## Pitfalls from practice

- **Bus-powered interface on a weak USB port.** A bus-powered interface can draw
  enough current over USB for the digital section (enumeration, power LED) but
  too little for the analog output stage -- then the outputs are silent and the
  signal LEDs stay dark, **without** the kernel reporting any error. Fix: a
  **USB 3 port** (delivers more current) or a powered USB hub. On the GIGAPORT
  eX this was exactly the cause of silent outputs.

- **HAOS as a VM (e.g. Proxmox) with USB passthrough.** USB audio is isochronous
  and fragile over virtualization. Pass the interface's **whole USB host
  controller through as a PCIe device** -- in Proxmox: the VM's *Hardware → Add →
  PCI Device*, the USB controller -- rather than passing the single USB device.
  QEMU's per-device USB passthrough drops isochronous audio far more readily than
  a passed-through controller. Find the controller the interface hangs off from
  the device's ALSA name (e.g. `… at usb-0000:06:10.0-…` → PCI `06:10.0`), make
  sure it sits in its own IOMMU group, and pass that controller; the interface
  must be plugged into a port on it.

  Caveat, so this is not mistaken for a cure-all: in our ESI GIGAPORT eX case the
  isochronous stream reached the device fine even over passthrough (the device
  locked to the clock), and the real fix was USB **power** -- a USB 3 port, see
  the bullet above. Rule of thumb: if it works on bare metal (a laptop) but not
  in the VM, controller passthrough is the suspect; if it fails on bare metal
  too, look at power and cabling.

- **No sound? Check the signal LEDs first.** The 8 signal LEDs show audio present
  per channel. If they light, the signal is arriving -- even with no speakers
  connected. LEDs first, then the chain behind them.

## How it works

An add-on runs once per slug, and the player listens on a fixed port (8928).
Five containers sharing the host's network could only fight over the same port
-- in **one** container it is a count: `sendspin-cli` takes a `--port`, and its
help names exactly two players on one host as the case for it. That is why every
zone here runs in one container, each on its own port.

Each zone gets its own stable `SENDSPIN_ID` (from an identifier generated once
in `/data`). Without it they would all derive the same one from the NIC MAC, and
a server files volume, group membership and pairing under that id -- every zone's
settings would then land on whichever connected last.

The add-on uses the image from
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon),
with its own service in place of the single-player service.

## Inputs (not supported yet)

This add-on splits **outputs** into zones. Audio **inputs** of an interface
(line-in, turntable, microphone) are not supported -- not even when the card has
inputs (the ESI GIGAPORT eX, for example, offers `input:analog-stereo`).

The reason is not the add-on but one layer below: Music Assistant does have a
server-side provider for it (`sendspin_source` -- "Play live audio inputs
(line-in, turntable, microphone) from Sendspin clients that support the source
role"), but the player this add-on builds on, `sendspin-cli`, **does not
implement the source role** and has no capture function. An input cannot even be
registered as a source, independent of this add-on.

Once `sendspin-cli` supports the source role (no open upstream issue for it at
present), this could follow. Until then the path for a line-in source is a
separate stream (e.g. `parec`/`ffmpeg` → HTTP) added to Music Assistant as a
radio source -- without sync to the zones and without `line_sense`.

## Maintenance / updating

This add-on inherits its image from upstream
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon)
(`FROM ghcr.io/music-assistant/local-audio-addon:<tag>` in the Dockerfile). From
there come `sendspin-cli`, `pactl`, s6-overlay and the security-reviewed base
image. The zone logic of this add-on is independent of it.

**Automatic:** the workflow `.github/workflows/upstream-bump.yml` checks the
latest upstream release weekly (and on demand) and opens a pull request on a new
version that raises the `FROM` tag in the Dockerfile and bumps the add-on
`version` in config.yaml (as a patch), with a CHANGELOG entry and a test
checklist. For the workflow to open PRs, enable once in the repo settings:
**Settings → Actions → General → "Allow GitHub Actions to create and approve
pull requests"**.

Note that the two versions are separate: the `FROM` tag is the upstream *image*
version, while `version` in config.yaml is this add-on's own version (its own
line, bumped per patch so the Supervisor shows "update available").

**Manual (fallback):**

```sh
# find the latest upstream tag
gh api repos/music-assistant/local-audio-addon/releases/latest --jq .tag_name
# set FROM ...:<new> in the Dockerfile, and bump version: "<x.y.z+1>" in config.yaml
```

**Test after every bump** -- a bump is not done until this holds:

1. The app **rebuild** completes. The assertion in the Dockerfile catches a
   restructuring of the s6 services in the base image as a **red build**, rather
   than letting it pass silently (a renamed service would otherwise start beside
   ours and bring back the port-8928 fight).
2. `docker exec hassio_audio pactl list sinks short` shows the zone sinks
   (`out_*`).
3. The app log shows one `handshake complete` per zone.
4. A test tone per zone comes out of the expected output.

Multi-channel is deliberately *outside* the Music Assistant core per upstream
(PR music-assistant/server#5132 was closed "Addressed outside Music Assistant
Core"). This community add-on is therefore the intended place for the zone
split; upstream stays the single player.
