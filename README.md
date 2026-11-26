# parrot-gui

Parrot OS (Security edition) in Docker with an XFCE desktop you can reach from a web browser (noVNC), an RDP client, or a VNC client.

It is based on [qeeqbox/docker-images](https://github.com/qeeqbox/docker-images) (`parrot/`), with these changes:

- noVNC and websockify are installed from Parrot's signed apt repo, not cloned from GitHub at an unpinned commit.
- Nothing is downloaded from third-party sites. The wallpaper comes from the `parrot-wallpapers` package.
- Tor is not started automatically.
- Raw VNC (5900) listens on localhost only by default.
- You can set passwords through environment variables. Any you leave unset are random.

## Requirements

- Docker (tested with 29.x on WSL2)
- Disk space: about 2–3 GB for the desktop only, 15+ GB with `parrot-tools-full`

## Build

```bash
cd parrot-gui

# Full image, with every Parrot security tool (large, slow to build)
docker build -t parrot-gui .

# Desktop only, no security tools (fast)
docker build --build-arg PARROT_TOOLS= -t parrot-gui:desktop .

# Pick your own tool metapackages or packages
docker build --build-arg PARROT_TOOLS="parrot-tools-web parrot-tools-password nmap" -t parrot-gui:custom .
```

| Build arg      | Default             | Meaning                                              |
|----------------|---------------------|------------------------------------------------------|
| `PARROT_TOOLS` | `parrot-tools-full` | Packages installed on top of the desktop. Empty = none. |

To list the tool metapackages available:

```bash
docker run --rm parrotsec/core:latest bash -c 'apt-get update -qq && apt-cache search ^parrot-tools'
```

## Run

```bash
docker run -d --name parrot \
  --cap-add=NET_ADMIN \
  -p 6080:6080 -p 3389:3389 \
  parrot-gui

docker logs parrot      # prints the generated passwords
```

Then connect:

| Method  | Address                            | Login                                  |
|---------|------------------------------------|----------------------------------------|
| Browser | http://localhost:6080/vnc.html     | VNC password                           |
| RDP     | `localhost:3389` (mstsc, Remmina)  | user `xuser` + xuser password          |
| VNC     | `localhost:5900` (only if enabled, see below) | VNC password               |

The desktop user is `xuser`, which has `sudo`.

### Fixed passwords

```bash
docker run -d --name parrot --cap-add=NET_ADMIN \
  -p 6080:6080 -p 3389:3389 \
  -e ROOT_PASSWORD='change-me-root' \
  -e USER_PASSWORD='change-me-user' \
  -e VNC_PASSWORD='vncpass1' \
  parrot-gui
```

### Environment variables

| Variable        | Default     | Meaning                                                        |
|-----------------|-------------|----------------------------------------------------------------|
| `ROOT_PASSWORD` | random      | Password for `root`                                            |
| `USER_PASSWORD` | random      | Password for `xuser` (RDP login, sudo)                         |
| `VNC_PASSWORD`  | random      | VNC/noVNC password. Only the first 8 characters are used.      |
| `VNC_LOCALHOST` | `yes`       | `no` makes raw VNC on 5900 reachable from outside the container |
| `RESOLUTION`    | `1920x1080` | Starting size of the VNC/noVNC desktop                         |

### Raw VNC client access

```bash
docker run -d --name parrot --cap-add=NET_ADMIN \
  -p 6080:6080 -p 3389:3389 -p 5900:5900 \
  -e VNC_LOCALHOST=no \
  parrot-gui
```

## HTB / VPN usage

To run OpenVPN inside the container, give it the tun device:

```bash
docker run -d --name parrot \
  --cap-add=NET_ADMIN --device /dev/net/tun \
  -p 6080:6080 -p 3389:3389 \
  -v "$PWD/work:/home/xuser/work" \
  parrot-gui

docker cp lab.ovpn parrot:/home/xuser/work/
docker exec -it parrot openvpn --config /home/xuser/work/lab.ovpn
```

If `openvpn` is missing (for example in a desktop-only build), install it with `docker exec parrot bash -c 'apt-get update && apt-get install -y openvpn'`.

With `-v`, files in `/home/xuser/work` stay on the host after the container is removed. Fix ownership if needed with `docker exec parrot chown -R xuser:xuser /home/xuser/work`.

## Day-to-day commands

```bash
docker exec -it parrot bash                 # root shell
docker exec -it -u xuser parrot bash        # shell as xuser
docker stop parrot && docker start parrot   # restart (new random passwords unless set via -e)
docker rm -f parrot                         # delete the container
```

Change the resolution from a terminal inside the desktop:

```bash
xrandr -s 1600x900
```

For RDP, set the resolution in your RDP client before connecting.

## Logs and troubleshooting

```bash
docker exec parrot supervisorctl -c /etc/supervisor/supervisord.conf status
docker exec parrot ls /var/log/supervisor/       # vnc.log, novnc.log, xrdp.log, ...
```

- **Browser shows "Failed to connect":** check that `vnc` is RUNNING in the status output and look at `vnc.log`.
- **RDP logs in to a black screen:** if a noVNC session is open, close it and reconnect. XFCE doesn't always run two sessions for the same user cleanly.
- **Port already in use:** map different host ports, for example `-p 16080:6080 -p 13389:3389`.

## Security notes

- Don't publish ports 6080, 3389 or 5900 on a public interface. To keep them local-only, bind them to loopback: `-p 127.0.0.1:6080:6080 -p 127.0.0.1:3389:3389`.
- Passwords are printed to `docker logs`. Anyone with Docker access on the host can read them.
- noVNC is plain HTTP. For remote access, use an SSH tunnel (`ssh -L 6080:localhost:6080 host`) rather than exposing it.

## Files

| File                               | Purpose                                         |
|------------------------------------|-------------------------------------------------|
| `Dockerfile`                       | Image build                                     |
| `entrypoint.sh`                    | Sets passwords, prints connection info, starts supervisord |
| `supervisord.conf`                 | Runs dbus, TigerVNC, noVNC (websockify), xrdp   |
| `Adwaita-dark-Xfce-with-Qbox-mw4/` | GTK/xfwm4 theme (from qeeqbox, `kali/` copy)     |
| `xfce-perchannel-xml/`             | XFCE panel, desktop and theme defaults          |
| `helpers.rc`                       | XFCE default applications                       |
