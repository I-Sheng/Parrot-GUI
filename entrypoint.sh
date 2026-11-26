#!/bin/bash
# Sets credentials (from env or random), then hands off to supervisord.
#   ROOT_PASSWORD, USER_PASSWORD, VNC_PASSWORD  - optional; random if unset
#   VNC_LOCALHOST=yes|no                        - expose raw VNC 5900 outside the container (default: yes = localhost only)
#   RESOLUTION=1920x1080                        - initial VNC desktop size
set -e

gen() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16; }

ROOT_PASSWORD=${ROOT_PASSWORD:-$(gen)}
USER_PASSWORD=${USER_PASSWORD:-$(gen)}
VNC_PASSWORD=${VNC_PASSWORD:-$(gen)}
export VNC_LOCALHOST=${VNC_LOCALHOST:-yes}
export RESOLUTION=${RESOLUTION:-1920x1080}

echo "root:${ROOT_PASSWORD}" | chpasswd
echo "xuser:${USER_PASSWORD}" | chpasswd

install -d -o xuser -g xuser -m 700 /home/xuser/.vnc
printf '%s\n' "${VNC_PASSWORD:0:8}" | vncpasswd -f > /home/xuser/.vnc/passwd
chown xuser:xuser /home/xuser/.vnc/passwd
chmod 600 /home/xuser/.vnc/passwd
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0

cat <<EOF

Parrot OS GUI container
-----------------------
root password  : ${ROOT_PASSWORD}
xuser password : ${USER_PASSWORD}   (RDP login / sudo)
VNC password   : ${VNC_PASSWORD:0:8}   (noVNC / VNC; VNC uses max 8 chars)

Web : http://localhost:6080/   (publish with -p 6080:6080)
RDP : localhost:3389           (publish with -p 3389:3389)

EOF
unset ROOT_PASSWORD USER_PASSWORD VNC_PASSWORD

exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
