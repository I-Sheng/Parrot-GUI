# Parrot OS (Security edition) with an XFCE desktop reachable via noVNC (web), VNC and RDP.
# Based on qeeqbox/docker-images (parrot/), reviewed and hardened:
#   - noVNC/websockify from Parrot's signed apt repo instead of unpinned `git clone`
#   - no third-party wallpaper download (uses parrot-wallpapers package)
#   - Tor is NOT auto-started
#   - raw VNC bound to localhost by default; passwords can be set via env
#
# Build:  docker build -t parrot-gui .
#         docker build --build-arg PARROT_TOOLS=parrot-tools-full -t parrot-gui:full .
FROM parrotsec/core:latest

LABEL org.opencontainers.image.title="parrot-gui" \
      org.opencontainers.image.description="Parrot OS with XFCE over noVNC/VNC/RDP"

ARG DEBIAN_FRONTEND=noninteractive
# Tool metapackage(s). parrot-tools-full is very large (~10+ GB);
# set to "" for a bare desktop, or pick smaller metapackages.
ARG PARROT_TOOLS="parrot-tools-full"

# Desktop + remote access
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xfce4 xfce4-terminal xfce4-whiskermenu-plugin xfce4-taskmanager xfce4-notifyd \
        xorg dbus dbus-x11 at-spi2-core \
        gnome-themes-extra gtk2-engines-pixbuf gtk2-engines-murrine \
        numix-icon-theme numix-icon-theme-circle fonts-ubuntu fonts-dejavu \
        parrot-wallpapers \
        thunar mousepad ristretto evince file-roller firefox-esr \
        xrdp xorgxrdp tigervnc-standalone-server tigervnc-tools novnc python3-websockify \
        supervisor sudo locales ca-certificates procps iproute2 \
        bash-completion vim less && \
    rm -rf /var/lib/apt/lists/*

# Security tooling (separate layer so the desktop layer stays cached)
RUN if [ -n "$PARROT_TOOLS" ]; then \
        apt-get update && \
        apt-get install -y $PARROT_TOOLS && \
        rm -rf /var/lib/apt/lists/* ; \
    fi

RUN sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Quieter xrdp logging; start XFCE for RDP sessions
RUN sed -i -e 's/LogLevel=DEBUG/LogLevel=INFO/g' \
           -e 's/EnableSyslog=true/EnableSyslog=false/g' /etc/xrdp/xrdp.ini /etc/xrdp/sesman.ini && \
    echo "xfce4-session" > /etc/skel/.xsession && \
    mkdir -p /var/run/dbus /var/log/supervisor

RUN useradd -m -s /bin/bash -G sudo xuser

# Theme + XFCE defaults (from qeeqbox/docker-images, kali/ copy — the parrot/ copy is incomplete)
COPY Adwaita-dark-Xfce-with-Qbox-mw4 /usr/share/themes/Adwaita-dark-Xfce-with-Qbox-mw4
COPY xfce-perchannel-xml /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
COPY --chown=xuser:xuser xfce-perchannel-xml /home/xuser/.config/xfce4/xfconf/xfce-perchannel-xml
COPY helpers.rc /etc/xdg/xfce4/helpers.rc

RUN ln -sf /usr/share/icons/Numix-Circle /usr/share/icons/KXicons && \
    ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html && \
    WP=$(find /usr/share/backgrounds /usr/share/wallpapers -type f \( -iname '*.jpg' -o -iname '*.png' \) 2>/dev/null | grep -i parrot | head -n1) && \
    mkdir -p /usr/share/backgrounds/xfce && \
    if [ -n "$WP" ]; then ln -sf "$WP" /usr/share/backgrounds/xfce/default.jpg; fi && \
    cp /etc/skel/.xsession /home/xuser/.xsession && chown xuser:xuser /home/xuser/.xsession

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# 6080 = noVNC (browser), 3389 = RDP, 5900 = raw VNC (only if VNC_LOCALHOST=no)
EXPOSE 6080 3389 5900
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
