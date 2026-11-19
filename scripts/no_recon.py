#!/usr/bin/env python3
"""No-reconnaissance check (AGENTS.md "Project rules", "No reconnaissance"; the Administrator, 2026-11-19).

Reads PowerShell text and reports each word that finds hosts, pings, tests a port, looks up a name, maps a network,
searches a directory or opens a session on another computer. It is a word search, not a proof: it reads comments and
strings too, so a hit means "a person must look", and code that hides a call from a word search passes (for example a short type
name after "using namespace").
  python3 scripts/no_recon.py          reads the engine sources and the sample app's scripts; exit 1 on a hit
  python3 scripts/no_recon.py --test   the check proves itself: each planted word is found, each allowed text passes
  no_recon.find(text)                  scripts/check_apps.py reads each real app's built bundles with it (NOTE lines)
Output: one line per hit (file:line: kind: word), then "NORECON files=N hits=M". Pass = hits=0.
Run by scripts/check.local.sh in both lanes. Needs Python 3 only.
Network: none
Writes: none
Credentials: none
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# What the plain run reads: every file the bundle is made of, the build, and the sample app's scripts.
SOURCES = ('engine/ps/*.ps1', 'engine/ps/window/*.ps1', 'engine/rade_ui.ps1', 'engine/rade_build.py', 'tests/fixture-app/**/*.ps1')
# Kind and pattern, matched in any letter case. Add a word here when a review finds a new way to do the same thing.
# Allowed on purpose, so no pattern names them: NetworkInformation.IPGlobalProperties (the NIPR guardrail reads this
# computer's own domain name) and Sockets.SocketException (an error kind the reach check names in its detail).
RULES = (
    ('host or port test', r'\b(Test-Connection|Test-NetConnection|Test-WSMan)\b'),
    ('ping', r'\bping(\.exe)?\b|\bWin32_PingStatus\b'),
    ('name lookup', r'\b(Resolve-DnsName|nslookup|GetHostEntry|GetHostAddresses|GetHostByName)\b|\[(System\.)?Net\.Dns\]'),
    ('network map', r'\b(Get-NetNeighbor|Get-NetRoute|Find-NetRoute|Get-NetTCPConnection|tracert|pathping|nbtstat|netstat|arp|nmap|portqry|nltest)\b|\bnet(\.exe)?\s+view\b|\bqwinsta\b'),
    ('raw socket', r'\bSockets\.(TcpClient|UdpClient|TcpListener|Socket)\b'),
    ('directory search', r'\bGet-AD[A-Za-z]+\b|\bDirectory(Searcher|Entry)\b|\[adsi(searcher)?\]'),
    ('other computer', r'\b(New-PSSession|Enter-PSSession|New-CimSession)\b|(?<!\w)-ComputerName\b'),
)
# Self-test data: each FOUND text must give exactly one hit; each ALLOWED text must give none.
FOUND = ('Test-NetConnection $h -Port 443', 'ping.exe $h', '& PING $h', 'Resolve-DnsName $h', '[System.Net.Dns]::GetHostName()',
         '[Net.Dns]::x', 'net  view', 'arp -a', 'New-Object System.Net.Sockets.TcpClient', 'Get-ADComputer -Filter *',
         'New-Object DirectoryServices.DirectorySearcher', 'Get-CimInstance Win32_Bios -ComputerName $h', 'Enter-PSSession $h',
         'net.exe view', 'Get-CimInstance Win32_PingStatus', '[adsisearcher]"(objectClass=computer)"', '[ADSI]"LDAP://x"', 'qwinsta /server:x')
ALLOWED = ('[System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName',
           '$x -is [System.Net.Sockets.SocketException]', 'shipping and mapping', 'Connect-PnPOnline -Url $site -UseWebLogin',
           '$env:COMPUTERNAME', 'Start-Process -FilePath $url')


def find(text):
    """Every hit in `text` as (line number from 1, kind, the word found), in line order."""
    hits = []
    for number, line in enumerate(text.splitlines(), 1):
        for kind, pattern in RULES:
            for m in re.finditer(pattern, line, re.IGNORECASE):
                hits.append((number, kind, m.group(0)))
    return hits


def self_test():
    """Check the rules against FOUND and ALLOWED. Returns the list of problems (empty = the check works)."""
    bad = ['not found: ' + t for t in FOUND if len(find(t)) != 1]
    bad += ['wrongly found: ' + t for t in ALLOWED if find(t)]
    if find('a\nb\nping x') != [(3, 'ping', 'ping')]:
        bad.append('line number or kind is wrong')
    return bad


def main():
    """Run the self-test (--test) or read SOURCES; print the result lines and exit 1 on a problem."""
    if sys.argv[1:] == ['--test']:
        bad = self_test()
        print('\n'.join(bad + ['NORECON self-test %s (%d found, %d allowed)' % ('FAIL' if bad else 'ok', len(FOUND), len(ALLOWED))]))
        sys.exit(1 if bad else 0)
    files = sorted(f for g in SOURCES for f in ROOT.glob(g))
    hits = 0
    for f in files:
        for number, kind, word in find(f.read_text(encoding='utf-8', errors='replace')):
            print('%s:%d: %s: %s' % (f.relative_to(ROOT), number, kind, word))
            hits += 1
    print('NORECON files=%d hits=%d' % (len(files), hits))
    sys.exit(1 if hits or len(files) < 20 else 0)   # fewer than 20 files = the search did not read the engine


if __name__ == '__main__':
    main()
