# Changelog

## 0.1.1

- Base image raised to 0.2.0 (was 0.1.13). Test before merging:
  rebuild, then check the zone sinks and one handshake per zone.

## 0.1.0

Initial release.

- Splits a multi-channel output into independent stereo zones and plays each as
  its own Sendspin player for Music Assistant -- all players in one container,
  each on its own port (8928 upward).
- Creates the `module-remap-sink` sinks itself at startup, reading the output's
  channel map to compute the possible pairs. A watchdog restarts a stopped
  player and recreates the sinks if a restart of the audio plugin removes them.
- Zones are configured in the add-on options; sink, display name and server per
  zone. No manual editing of files on the host.
- Pins the master sink to 100% and suspends/resumes it after creating the zones
  -- against a volume saved by `module-device-restore` that would otherwise
  attenuate every zone invisibly.
