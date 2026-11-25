"""Compatibility decoder for NSNumber-backed Preferences switch (v2.10.1).

The Objective-C Settings bundle can store the enabled switch as plist <integer>1
instead of <true/>. Avoid identity comparison ('is True') in the LPM worker.
The shipped worker inlines this helper.
"""

def lpm_auto_enabled(preference):
    value = preference.get("enabled")
    return type(value) in (bool, int) and value == 1


if __name__ == "__main__":
    cases = [(True, True), (False, False), (1, True), (0, False),
             (2, False), ("1", False), (1.0, False), (None, False)]
    for stored, expected in cases:
        result = lpm_auto_enabled({"enabled": stored})
        assert result is expected, (stored, result, expected)
    assert not lpm_auto_enabled({})
    print("LPM preference decoder: PASS (9 cases)")
