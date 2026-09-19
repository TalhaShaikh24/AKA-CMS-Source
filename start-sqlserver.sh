#!/bin/bash
# Restart SQL Server on this dev VM.
# The container's /sys/fs/cgroup is unreadable by the mssql user (EACCES on
# missing memory.max), which crashes sqlservr during startup. Workaround:
# bind-mount an overlay exposing the real cgroup files plus a fake
# memory.max, then start the server - all in ONE shell so the mount is
# visible (mounts do not persist across exec sessions here).
# NOTE: the overlay must expose ALL real cgroup files (via symlinks); a
# 2-file fake dir crashes sqlservr. SA password: DevPass2026Strong
# (set once via mssql-conf set-sa-password; stored in master).
set -e
mkdir -p /tmp/cgroup-real /tmp/cgroup-fake
mount --bind /sys/fs/cgroup /tmp/cgroup-real 2>/dev/null || true
for f in /tmp/cgroup-real/*; do
  bn=$(basename "$f")
  [ -e "/tmp/cgroup-fake/$bn" ] || ln -sf "/tmp/cgroup-real/$bn" "/tmp/cgroup-fake/$bn"
done
echo "max" > /tmp/cgroup-fake/memory.max
chmod 755 /tmp/cgroup-fake
chmod 644 /tmp/cgroup-fake/memory.max
mount --bind /tmp/cgroup-fake /sys/fs/cgroup
# Avoid a second instance: mssql-conf refuses when one is already running.
if ps -eo args | grep -q "[s]qlservr"; then
  echo "SQL Server already running."
else
  su mssql -s /bin/bash -c "nohup /opt/mssql/bin/sqlservr > /tmp/sqlservr-main.log 2>&1 &"
fi
echo "SQL Server starting, waiting for readiness..."
for i in $(seq 1 24); do
  if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'DevPass2026Strong' -C -Q "SELECT 1" > /dev/null 2>&1; then
    echo "SQL Server is ready."
    exit 0
  fi
  sleep 10
done
echo "SQL Server did not become ready in time."; exit 1
