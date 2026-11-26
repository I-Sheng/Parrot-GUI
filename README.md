# parrot-gui

Parrot OS with an XFCE desktop in your browser.

## 1. Build

```bash
cd parrot-gui
docker build -t parrot-gui .
```

## 2. Run

```bash
docker run -d --name parrot \
  --cap-add=NET_ADMIN --device /dev/net/tun \
  -p 127.0.0.1:6080:6080 \
  -v "$PWD/work:/home/xuser/work" \
  parrot-gui
```

## 3. Get the passwords

```bash
docker logs parrot
```

## 4. Open the desktop

Go to http://localhost:6080/vnc.html and log in with the **VNC password**.

## 5. Connect the VPN

Put your `.ovpn` file in the `work/` folder, then open a terminal in the desktop and run:

```bash
sudo openvpn --config ~/work/lab.ovpn
```

Use the **xuser password** for sudo. Keep this terminal open while you work.

## Stop / start

```bash
docker stop parrot
docker start parrot     # new passwords each start; check docker logs again
```
