import re, subprocess, sys

prev, cur = sys.argv[1], sys.argv[2]
log = subprocess.run(
    ["git", "log", "--oneline", f"{prev}..{cur}"],
    capture_output=True, text=True
).stdout
lines = [l.strip() for l in log.strip().split("\n") if l.strip()]

added = {}
removed = []
modified = []
wips = {}

pat_add = re.compile(
    r'\+(?P<name>\w+)(?:{(?P<subs>[^}]+)})?(?::wip<(?P<wip>[^>]+)>)?$'
)
pat_rem = re.compile(r"\-(?P<name>\w+)")
pat_mod = re.compile(r"~(?P<name>\w+)")

for line in lines:
    parts = line.split(" ", 1)
    if len(parts) < 2:
        continue
    msg = parts[1]
    msg = re.sub(r"!\S+", "", msg).strip()

    m = pat_add.match(msg)
    if m:
        name = m.group("name")
        subs = m.group("subs")
        wipv = m.group("wip")
        if wipv:
            wips[name] = wipv
        elif subs:
            added[name] = subs.split(",")
        else:
            added.setdefault(name, [])
        continue

    m = pat_rem.match(msg)
    if m:
        removed.append(m.group("name"))
        continue

    m = pat_mod.match(msg)
    if m:
        modified.append(m.group("name"))
        continue

out = []
if added:
    out.append("### Added")
    for name, subs in sorted(added.items()):
        if subs:
            out.append(f"  - {name}: {', '.join(subs)}")
        else:
            out.append(f"  - {name}")
if removed:
    h = "### Removed"
    if out:
        out.append("")
    out.append(h)
    for name in sorted(removed):
        out.append(f"  - {name}")
if modified:
    out.append("")
    out.append("### Modified")
    for name in sorted(modified):
        out.append(f"  - {name}")
if wips:
    out.append("")
    out.append("### Work in Progress")
    for name, ver in sorted(wips.items()):
        out.append(f"  - {name} (WIP, v{ver})")
if not out:
    out.append("Miscellaneous changes")
print("\n".join(out))
