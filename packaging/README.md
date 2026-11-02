# Hotspot Keepalive iOS rootless .deb (v0.2.0)

Builds this fork's keepawake, hshold, hotspot, misctl, and optional socksd components into a rootless deb.

Keeps same package identity **com.hotspotprobe.keepalive** as previously working v0.1.0, so Sileo can upgrade. **No VPN/pftun** to avoid upstream PF kernel panic risks. Settings are deliberately conservative, preserving the working keepawake configuration: KEEPAWAKE_ON_AC=0 and KEEPAWAKE_CHILDREN=hshold.

For diagnostics open Safari **on the iPhone 6s** and visit http://127.0.0.1:8765; panel is read-only and bound to localhost. Proxy script is included but intentionally not launched. None of the private API techniques are guaranteed on iOS 15. The locked client may consume more battery. Wi-Fi sync pairing is needed for TCP 62078.

The fork's upstream source code lives in the phone/ folder. No automatic backups are created.
