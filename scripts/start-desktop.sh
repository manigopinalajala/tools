#!/bin/bash
set -Eeuo pipefail

export HOME=/home/codespace
export DISPLAY=:1
export PATH=/opt/conda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

LOG=/tmp/codespace-desktop
mkdir -p "$LOG"

echo "Starting Linux desktop..."

# Start virtual display
if ! pgrep -f '^/usr/bin/Xvfb :1' >/dev/null; then
    nohup /usr/bin/Xvfb :1 -screen 0 1600x900x24 -ac \
        >"$LOG/xvfb.log" 2>&1 </dev/null &
fi

# Wait for display
for i in {1..20}; do
    if DISPLAY=:1 /usr/bin/xdpyinfo >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

DISPLAY=:1 /usr/bin/xdpyinfo >/dev/null 2>&1 || {
    echo "ERROR: X display unavailable"
    exit 1
}

# Start XFCE with D-Bus
if ! pgrep -u codespace -x xfce4-session >/dev/null; then
    nohup /opt/conda/bin/dbus-run-session -- \
        /usr/bin/xfce4-session \
        >"$LOG/xfce.log" 2>&1 </dev/null &
    sleep 5
fi

# Start VNC with password authentication
if ! pgrep -af '[x]11vnc.*rfbport 5900' >/dev/null; then
    nohup /usr/bin/x11vnc \
        -display :1 \
        -localhost \
        -forever -shared \
        -rfbauth /home/codespace/.vnc/passwd \
        -rfbport 5900 \
        >"$LOG/x11vnc.log" 2>&1 </dev/null &
fi

# Wait for VNC
for i in {1..15}; do
    if /usr/bin/ss -ltn | grep -q ':5900 '; then
        break
    fi
    sleep 1
done

/usr/bin/ss -ltn | grep -q ':5900 ' || {
    echo "ERROR: VNC server failed"
    exit 1
}

# Start noVNC
if ! /usr/bin/ss -ltn | grep -q ':6080 '; then
    nohup /usr/share/novnc/utils/novnc_proxy \
        --vnc localhost:5900 \
        --listen 6080 \
        >"$LOG/novnc.log" 2>&1 </dev/null &
fi

# Verify noVNC
for i in {1..15}; do
    if /usr/bin/ss -ltn | grep -q ':6080 '; then
        break
    fi
    sleep 1
done

/usr/bin/ss -ltn | grep -q ':6080 ' || {
    echo "ERROR: noVNC failed"
    exit 1
}

echo "SUCCESS: Linux desktop is ready!"
