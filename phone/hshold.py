#!/var/jb/usr/bin/python3
# Holds open connections to the lockdownd (TCP 62078) of every Personal Hotspot client (iPhone/iPad).
# While a connection is open the client's lockdownd holds a PreventUserIdleSystemSleep assertion
# ("com.apple.mobile.lockdownd.active-connection <Label>"). An iOS client on a hotspot network leaves it
# when it sleeps (link down, reason System Sleep); with the assertion it does not sleep. When the connection
# closes the client sleeps and leaves within about a second, so hshold never closes a socket itself (TCP
# keepalive finds dead connections) and keeps two connections per client: while one reconnects the other
# keeps the assertion. Runs as a child of keepawake.py.
# Also, wifid stops the hotspot 90 s after the last client leaves (MIS idle timer). While the hotspot is on,
# hshold asks misctl to re-arm discovery every 60 s, which restarts that timer. If the hotspot is off (mis=0)
# it is left alone. Without the misctl binary this part is skipped.
import os, plistlib, re, socket, struct, subprocess, threading, time

import hotspot

PORT = 62078
INTERVAL = 10      # seconds between QueryType requests
KEEPIDLE = 10      # also send TCP keepalives between requests (Darwin TCP_KEEPALIVE)
KEEPCNT = 6        # a dead client is dropped after ~70 s; a 60 s read timeout used to close the socket itself and put the client to sleep
REFUSED_BACKOFF = 30  # a freshly joined iPhone can open 62078 a few seconds late; a long backoff delayed the hold by minutes
MISCTL = os.environ.get('HSHOLD_MISCTL', '/var/jb/usr/local/bin/misctl')
REARM = 60         # wifid's idle timer is 90 s; disc 1 does not affect connected clients
LABELS = ('hshold', 'hshold-b')  # separate assertion names on the client
ARP = re.compile(r'\((\d+\.\d+\.\d+\.\d+)\) at ([0-9a-f:]+) on ' + re.escape(hotspot.IFACE))

active = set()
backoff = {}

def log(m):
    print(time.strftime('%F %T'), m, flush=True)

def clients():
    try:
        out = subprocess.run(['/var/jb/usr/sbin/arp', '-an', '-i', hotspot.IFACE], capture_output=True, text=True, timeout=10).stdout
    except Exception:
        return []
    own = hotspot.address()
    return [ip for ip, mac in ARP.findall(out) if ip != own]

def query(s, req):
    s.sendall(struct.pack('>I', len(req)) + req)
    hdr = s.recv(4, socket.MSG_WAITALL)
    if len(hdr) < 4:
        raise EOFError('closed by client')
    n = struct.unpack('>I', hdr)[0]
    return plistlib.loads(s.recv(n, socket.MSG_WAITALL))

def hold(ip, label):
    key = (ip, label)
    req = plistlib.dumps({'Label': label, 'Request': 'QueryType'})
    try:
        s = socket.create_connection((ip, PORT), timeout=5)
    except ConnectionRefusedError:
        backoff[ip] = time.time() + REFUSED_BACKOFF
        active.discard(key)
        return
    except Exception:
        active.discard(key)
        return
    start = time.time()
    try:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        s.setsockopt(socket.IPPROTO_TCP, getattr(socket, 'TCP_KEEPALIVE', 0x10), KEEPIDLE)
        s.setsockopt(socket.IPPROTO_TCP, getattr(socket, 'TCP_KEEPINTVL', 0x101), KEEPIDLE)
        s.setsockopt(socket.IPPROTO_TCP, getattr(socket, 'TCP_KEEPCNT', 0x102), KEEPCNT)
        s.settimeout(None)
        if query(s, req).get('Type') != 'com.apple.mobile.lockdown':
            backoff[ip] = time.time() + REFUSED_BACKOFF
            return
        log('%s %s holding' % (ip, label))
        while True:
            time.sleep(INTERVAL)
            query(s, req)
    except Exception as e:
        log('%s %s dropped after %ds: %r' % (ip, label, time.time() - start, e))
    finally:
        s.close()
        active.discard(key)

def misctl(*args):
    try:
        return subprocess.run([MISCTL] + list(args), capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception as e:
        return repr(e)

def rearm(was_on):
    on = misctl('status').startswith('mis=1')
    if on:
        misctl('disc', '1')
    if on != was_on:
        log('hotspot %s' % ('on, keeping discovery alive' if on else 'off'))
    return on

log('start')
use_misctl = os.access(MISCTL, os.X_OK)
if not use_misctl:
    log('%s not found: the hotspot may stop 90 s after the last client leaves' % MISCTL)
mis_on = None
next_rearm = 0
while True:
    now = time.time()
    if use_misctl and now >= next_rearm:
        mis_on = rearm(mis_on)
        next_rearm = now + REARM
    for ip in clients():
        if backoff.get(ip, 0) > now:
            continue
        for label in LABELS:
            if (ip, label) in active:
                continue
            active.add((ip, label))
            threading.Thread(target=hold, args=(ip, label), daemon=True).start()
    time.sleep(5)
