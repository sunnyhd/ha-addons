# Local Audio Zone 3

One Sendspin player for Music Assistant, playing to one PulseAudio sink.

Several of these split a multi-channel audio interface into independent stereo
zones — one player per pair of outputs, each with its own volume, queue and
group membership.

## Setting it up

1. Create the zone sinks once, in `/mnt/data/supervisor/audio/custom.pa`.
   The repository README has the recipe and the scripts that generate it.
2. Set **Audio output** here to `pulse:<sink>` — the sink this zone owns.
3. Set **Player name** to what the zone should be called in Music Assistant.
4. With more than one instance on this machine, set **Music Assistant server**
   as well. Every instance shares the host's network namespace, and each one
   that advertises over mDNS starts its own avahi-daemon — they would fight over
   port 5353. A server address suppresses the advertisement.

Left unconfigured this plays through the Audio panel like a single instance
would, which is a good way to check it starts at all.

This app runs the image published by
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon);
only the manifest differs.
