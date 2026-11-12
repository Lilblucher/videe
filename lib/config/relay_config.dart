/// Base URL for `dl_service` (coreripper/dl_service), the standalone
/// yt-dlp-backed relay that extracts TikTok/Instagram/etc. server-side and
/// re-streams the bytes under its own origin — the same trick ssstik.io and
/// fastdl.app use, so the platform CDN never sees (and never 403s) this
/// device's request.
///
/// CHANGE THIS before a real release: this default is the host-side address
/// reachable from inside the Waydroid test container used during
/// development (`waydroid0` bridge, see coreripper/CLAUDE.md's `dl_service`
/// section). On a real device this must point at the deployed service
/// (e.g. `https://dl.coreripper.site`), not a local bridge IP.
const String relayBaseUrl = String.fromEnvironment(
  'RELAY_BASE_URL',
  defaultValue: 'http://192.168.240.1:3002',
);
