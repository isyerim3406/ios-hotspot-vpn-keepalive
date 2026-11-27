#!/usr/bin/env python3
"""Reproducible v2.10.1 -> v2.10.2 LPM-only source patch.

Source: var/jb/usr/local/bin/classic-lpm-watch.py extracted from the
com.chatin.classicmanual 2.10.1 DEB. Never modifies the Classic motor,
Find My handling, PreferenceLoader UI, launchd jobs or SpringBoard bridge.

The v2.10.2 LPM worker consults *only* the MIS service state. The MIS
status is NOT equivalent to the Settings "Allow Others to Join" switch.
"""

from pathlib import Path
import hashlib
import sys

BEFORE = "444225b83d2edd5419a7080e40520564af4dacb0b932d113e43d36fcad289bcd"
AFTER = "b2fd18568b9ec28cfaea2eb74203a4d5226e5d98766ec42f68d0aa3e0f3f2923"

NEW_NETWORK_FUNCTION = """def hotspot_connection_state():
    \\"\\"\\"Low Power automation observes hotspot service state, not Wi-Fi peers.

    MIS=1 is positive evidence of active sharing, regardless of client count.
    MIS=0 must remain uninterrupted for 180 seconds before LPM is enabled.
    Any failure / ambiguous response is unknown, which must never enable LPM.
    In particular do NOT open probe sockets, read ARP or query Hosts.Current.

    Note: MIS state is not the Settings 'Allow Others to Join' switch state.
    \\"\\"\\"
    if not (os.path.isfile(MISCTL_PATH) and os.access(MISCTL_PATH, os.X_OK)):
        print('LPM NETWORK: misctl unavailable => unknown', flush=True)
        return 'unknown'
    try:
        response = subprocess.run((MISCTL_PATH, 'status'), capture_output=True,
                                  text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired) as ex:
        print('LPM NETWORK: misctl error %r => unknown' % (ex,), flush=True)
        return 'unknown'
    if response.returncode != 0:
        print('LPM NETWORK: misctl rc=%s => unknown' % response.returncode, flush=True)
        return 'unknown'
    value = re.search(r'(?<!\\w)mis=([01])(?!\\d)', response.stdout)
    if not value:
        print('LPM NETWORK: unrecognized misctl status => unknown', flush=True)
        return 'unknown'
    state = 'connected' if value.group(1) == '1' else 'off'
    print('LPM NETWORK: mis=%s => %s' % (value.group(1), state), flush=True)
    return state


"""

def patch(old: bytes) -> bytes:
    digest = hashlib.sha256(old).hexdigest()
    if digest != BEFORE:
        raise ValueError(f"Unexpected v2.10.1 source: SHA256 {digest}")
    source = old.decode("utf-8")
    lo = source.index("def connected_client_count():")
    hi = source.index("def atomic_plist(", lo)
    source = source[:lo] + NEW_NETWORK_FUNCTION + source[hi:]
    source = source.replace(
        "0 connected: LPM off. 180s verified client absence: LPM on.",
        "MIS=1 hotspot active: LPM off. MIS=0 for 180s: LPM on. No network probing.",
    )
    source = source.replace(
        "Independent LPM worker v2.10.1 SpringBoard bridge pid=",
        "Independent LPM worker v2.10.2 service-only monitor pid=",
    )
    source = source.replace(
        "elif network in ('off','empty'):",
        "elif network == 'off':",
    )
    result = source.encode("utf-8")
    digest = hashlib.sha256(result).hexdigest()
    if digest != AFTER:
        raise AssertionError(f"Patched result SHA256 mismatch: {digest}")
    return result

if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python3 patch_lpm_v2102.py extracted-v2.10.1.py output-v2.10.2.py")
    old_path, new_path = map(Path, sys.argv[1:])
    new_path.write_bytes(patch(old_path.read_bytes()))
    print("LPM-only patch verified:", AFTER)
