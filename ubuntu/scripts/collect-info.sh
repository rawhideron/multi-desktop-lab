#!/bin/bash
set -euo pipefail

OUTDIR="/tmp/desktop-troubleshoot-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUTDIR"

echo "Collecting XRDP and session logs to $OUTDIR"
cp /var/log/xrdp.log "$OUTDIR/" 2>/dev/null || true
cp /var/log/xrdp-sesman.log "$OUTDIR/" 2>/dev/null || true
cp /var/log/xrdp-sesman.* "$OUTDIR/" 2>/dev/null || true

# find any xorgxrdp logs in /home
for d in /home/*; do
  if [ -d "$d" ]; then
    shopt -s nullglob
    for f in "$d"/.xorgxrdp.*.log; do
      cp "$f" "$OUTDIR/" 2>/dev/null || true
    done
    shopt -u nullglob
  fi
done

echo "Collecting environment and system state"
env > "$OUTDIR/env.txt" 2>/dev/null || true
ps aux > "$OUTDIR/ps.txt" 2>/dev/null || true
mount > "$OUTDIR/mounts.txt" 2>/dev/null || true
df -h > "$OUTDIR/df.txt" 2>/dev/null || true
ls -la /home > "$OUTDIR/home-listing.txt" 2>/dev/null || true

echo "Gathering journal/syslog (if available)"
if command -v journalctl >/dev/null 2>&1; then
  journalctl -n 200 > "$OUTDIR/journal.txt" 2>/dev/null || true
fi
cp /var/log/syslog "$OUTDIR/" 2>/dev/null || true

echo "Creating archive /tmp/desktop-troubleshoot.tar.gz"
tar -C /tmp -czf /tmp/desktop-troubleshoot.tar.gz "$(basename "$OUTDIR")" >/dev/null 2>&1 || true

echo "Done — archive created at /tmp/desktop-troubleshoot.tar.gz"
echo "To copy it to host: docker cp <container>:/tmp/desktop-troubleshoot.tar.gz ."
