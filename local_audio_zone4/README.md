# Local Audio Zone 4

One Sendspin player for Music Assistant, playing to one PulseAudio sink.

Several of these split a multi-channel audio interface into independent stereo
zones — one player per pair of outputs, each with its own volume, queue and
group membership.

## Setting it up

1. Create the zone sinks once, in `/mnt/data/supervisor/audio/custom.pa`.
   The repository README has the recipe and the scripts that generate it.
2. Set **Audio output** here to `pulse:<sink>` — the sink this zone owns.
3. Set **Player name** to what the zone should be called in Music Assistant.
4. Set **Music Assistant server** to `<host>:8927`. This one is required, not
   optional: each instance runs in its own network namespace so that they do not
   all fight over the player's fixed port 8928, and without the host's network
   there is no mDNS to be discovered on. The player dials out to the server
   instead, and everything runs over that connection.

Without a server address the player waits to be found, and nothing will find it.

This app runs the image published by
[music-assistant/local-audio-addon](https://github.com/music-assistant/local-audio-addon);
only the manifest differs.
