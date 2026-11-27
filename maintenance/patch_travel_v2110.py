#!/usr/bin/env python3
"""Reproducible road-mode changes for installed v2.10.1 runtime files.

Usage:
 python3 maintenance/patch_travel_v2110.py /path/to/extracted/var/jb/usr/local/bin

The original Classic Keepawake 0.2.0 package and Find My logic are untouched.
The UI source for the separate switch is in manual-status-ui/.
"""
from pathlib import Path
import hashlib
import sys

EXPECTED = {
    "classic-manual-apply.py": (
        "58d2cf99e748ac5c364dc589a73c1de43a5f1df833fab81f8aa06200bcaa1a1f",
        "bd3ac20c80243fd812346e929c401223205be2ef78ae4660e1d3cb9ab3e67b2c"),
    "classic-lpm-watch.py": (
        "444225b83d2edd5419a7080e40520564af4dacb0b932d113e43d36fcad289bcd",
        "3dc3080df209bade38946fa5b47ea383f8924dca846b2f4bc22e86019dbf1e1c"),
}

def replace_once(s, a, b):
    if s.count(a) != 1:
        raise ValueError("Unexpected runtime revision or duplicate anchor: " + a[:100])
    return s.replace(a, b, 1)

def patch_classic(s):
    s=replace_once(s,
      "MISCTL_PATH = '/var/jb/usr/local/bin/misctl'",
      "MISCTL_PATH = '/var/jb/usr/local/bin/misctl'\nTRAVEL_PREFS = '/var/mobile/Library/Preferences/com.chatin.classictravel.plist'")
    s=replace_once(s, "class AutoTransition:\n",
'''def travel_mode_enabled():
    """Independent road-mode override; invalid preference fails closed."""
    try:
        with open(TRAVEL_PREFS, 'rb') as fp:
            prefs = plistlib.load(fp)
        value = prefs.get('enabled') if isinstance(prefs, dict) else None
        return type(value) in (bool, int) and value == 1
    except (OSError, ValueError, plistlib.InvalidFileException, TypeError):
        return False


class AutoTransition:
''')
    s=replace_once(s,
      "def step(self,state,now,enabled,revision,auto_stopped=False):",
      "def step(self,state,now,enabled,revision,auto_stopped=False,travel_mode=False):")
    s=replace_once(s,
      "        self.last_revision=revision\n        absent=state in ('off','empty')",
'''        self.last_revision=revision
        if travel_mode:
            # The iOS tethering service may temporarily report no clients or
            # even OFF during loss of cellular registration. Never stop the
            # already-running original engine based on this ambiguity.
            self.absent_since = None
            self.was_absent = False
            self.last_state = state
            if not enabled and auto_stopped and not self.manual_block:
                # Only revive a controller-owned automatic stop; a manual OFF
                # remains authoritative, even in travel mode.
                self.auto_stopped = False
                return 'on'
            return None
        absent=state in ('off','empty')''')
    s=replace_once(s,
      "Classic controller v2.9.0 (independent LPM worker) started",
      "Classic controller v2.11.0 (travel guard) started")
    s=replace_once(s,
'''            action = state_machine.step(state,now,current,revision,
                          bool(pref.get('autoStopped',False)))''',
'''            travel_mode = travel_mode_enabled()
            if travel_mode != getattr(state_machine, 'last_travel_mode', False):
                print('TRAVEL: guard', 'ON' if travel_mode else 'OFF',
                      '; preserving manual Classic switch', flush=True)
                state_machine.last_travel_mode = travel_mode
            action = state_machine.step(state,now,current,revision,
                          bool(pref.get('autoStopped',False)), travel_mode)''')
    return s

def patch_lpm(s):
    s=replace_once(s,
      "PREFS = '/var/mobile/Library/Preferences/com.chatin.classiclpm.plist'",
      "PREFS = '/var/mobile/Library/Preferences/com.chatin.classiclpm.plist'\nTRAVEL_PREFS = '/var/mobile/Library/Preferences/com.chatin.classictravel.plist'\nCLASSIC_PREFS = '/var/mobile/Library/Preferences/com.chatin.classicmanual.plist'")
    s=replace_once(s, "def mode():\n",
'''def travel_mode_enabled():
    """Road mode defaults OFF and never changes the LPM switch preference."""
    value = read_plist(TRAVEL_PREFS).get('enabled')
    return type(value) in (bool, int) and value == 1


def classic_requested():
    """Manual Classic OFF must retain authority even if Travel Mode is ON."""
    value = read_plist(CLASSIC_PREFS).get('enabled')
    return type(value) in (bool, int) and value == 1


def mode():
''')
    s=replace_once(s,
      "Independent LPM worker v2.10.1 SpringBoard bridge",
      "Independent LPM worker v2.11.0 travel guard")
    s=replace_once(s,
"""            enabled=lpm_auto_enabled(preference)
            network=hotspot_connection_state() if enabled else 'disabled'""",
'''            enabled=lpm_auto_enabled(preference)
            road_mode=travel_mode_enabled() and classic_requested()
            # The road-mode override prevents a temporary cellular outage
            # from triggering Low Power Mode and affecting Wi-Fi recovery.
            # If LPM automation is manually OFF, leave power management alone.
            network=('travel-guard' if enabled and road_mode else
                     hotspot_connection_state() if enabled else 'disabled')''')
    s=replace_once(s,
      "            elif network=='connected':\n",
'''            elif network=='travel-guard':
                absent_since=None
                current=mode()
                if current is None:
                    message='Yol modu; guc modu okunamadi'
                elif current!=0 and time.monotonic()<next_set_attempt:
                    message='Yol modu; SpringBoard yaniti bekleniyor'
                elif current!=0 and not set_mode(0):
                    next_set_attempt=time.monotonic()+180
                    message='Yol modu; guc modu kapatilamadi'
                else:
                    message='Yol modu; LPM kapali, otomatik acilmayacak'
                    if old:
                        try: os.unlink(RECORD)
                        except FileNotFoundError: pass
            elif network=='connected':
''')
    return s

def main(folder):
    paths=[folder/name for name in EXPECTED]
    originals={p: p.read_bytes() for p in paths}
    for path,original in originals.items():
        before,after=EXPECTED[path.name]
        assert hashlib.sha256(original).hexdigest()==before, f"Bad original: {path.name}"
        patched=(patch_classic if path.name=="classic-manual-apply.py"
                 else patch_lpm)(original.decode("utf-8")).encode("utf-8")
        assert hashlib.sha256(patched).hexdigest()==after, f"Bad patch: {path.name}"
        originals[path]=patched
    for path,patched in originals.items():
        path.write_bytes(patched)
        print(path.name,hashlib.sha256(patched).hexdigest())

if __name__=="__main__":
    if len(sys.argv)!=2: raise SystemExit("Supply extracted package bin folder")
    main(Path(sys.argv[1]))
