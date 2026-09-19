#!/bin/bash
# AKA-CMS SQL Server bootstrap for this dev container.
# Mounts are per-exec-session here, so the cgroup overlay AND sqlservr AND
# mssql-conf must all run inside this one persistent session.
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
echo "OVERLAY OK: $(su mssql -s /bin/bash -c 'cat /sys/fs/cgroup/memory.max')"

# Set the SA password FIRST (mssql-conf starts its own sqlservr instance
# for this, so no other instance may be running).
export MSSQL_SA_PASSWORD='DevPass2026Strong'
/opt/mssql/bin/mssql-conf set-sa-password
echo "SA password configured"

# Start sqlservr as mssql in the background of THIS session.
su mssql -s /bin/bash -c "nohup /opt/mssql/bin/sqlservr > /tmp/sqlservr-main.log 2>&1 &"
echo "sqlservr launched"

# Wait for readiness via the errorlog.
for i in $(seq 1 30); do
  if grep -q "ready for client connections" /tmp/sqlservr-main.log 2>/dev/null; then
    echo "SQL Server is ready."
    break
  fi
  if grep -q "fatal error" /tmp/sqlservr-main.log 2>/dev/null; then
    echo "SQL Server crashed during startup."; tail -5 /tmp/sqlservr-main.log; exit 1
  fi
  sleep 5
done

# Verify.
if /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'DevPass2026Strong' -C -Q "SELECT 1" > /dev/null 2>&1; then
  echo "SA LOGIN OK"
else
  echo "SA LOGIN FAILED"; exit 1
fi

# Keep this session (and its mount namespace) alive for the SQL Server lifetime.
echo "Bootstrap complete. Holding namespace open."
sleep infinity
