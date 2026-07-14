#!/bin/bash
# ============================================================================
# Core Script: core_packages.sh
# SeederLinux Lite - Instalar pacotes essenciais
# ============================================================================
# Instala todos os pacotes necessarios para o funcionamento da estacao:
# ferramentas de rede, autenticacao, sistema grafico, utilitarios.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "03 - Instalar pacotes essenciais"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DESKTOP_ENV="{{DESKTOP_ENV}}"

echo ">>> Ambiente grafico: $DESKTOP_ENV"

# ============================================================
# Atualizar sistema
# ============================================================
echo ">>> Atualizando pacotes do sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade

# ============================================================
# Pacotes base do sistema
# ============================================================
echo ">>> Instalando pacotes base..."
BASE_PACKAGES=(
    wget
    curl
    gnupg
    ca-certificates
    lsb-release
    apt-transport-https
    software-properties-common
    unzip
    rsync
    htop
    vim
    nano
    less
    bash-completion
    net-tools
    dnsutils
    iproute2
    iputils-ping
    traceroute
    nmap
    tcpdump
    openssh-server
    openssh-client
    cifs-utils
    nfs-common
    smbclient
    policykit-1
    udisks2
    gvfs-backends
    gvfs-fuse
    fuse3
    libnotify-bin
    dbus-x11
    xdg-utils
    fonts-liberation
    fonts-noto
    fonts-noto-cjk
    fontconfig
)

apt-get install -y "${BASE_PACKAGES[@]}"

# ============================================================
# Pacotes de autenticacao (AD/Kerberos/SSSD)
# ============================================================
echo ">>> Instalando pacotes de autenticacao..."
AUTH_PACKAGES=(
    krb5-user
    krb5-clients
    samba
    samba-common
    samba-common-bin
    sssd
    sssd-tools
    libnss-sss
    libpam-sss
    adcli
    realmd
    oddjob
    oddjob-mkhomedir
    packagekit
    network-manager
    network-manager-gnome
)

apt-get install -y "${AUTH_PACKAGES[@]}"

# ============================================================
# Pacotes do ambiente grafico
# ============================================================
echo ">>> Instalando pacotes do ambiente grafico: $DESKTOP_ENV"
case "$DESKTOP_ENV" in
    cinnamon)
        apt-get install -y cinnamon cinnamon-core lightdm
        ;;
    mate)
        apt-get install -y mate mate-core mate-desktop-environment lightdm
        ;;
    gnome)
        apt-get install -y gnome gnome-core gdm3
        ;;
    xfce)
        apt-get install -y xfce4 xfce4-goodies lightdm
        ;;
    kde)
        apt-get install -y kde-plasma-desktop sddm
        ;;
    lxde)
        apt-get install -y lxde lightdm
        ;;
    *)
        echo ">>> AVISO: Ambiente grafico nao reconhecido: $DESKTOP_ENV"
        echo ">>> Instalando XFCE como fallback..."
        apt-get install -y xfce4 xfce4-goodies lightdm
        ;;
esac

# ============================================================
# Pacotes complementares
# ============================================================
echo ">>> Instalando pacotes complementares..."
EXTRA_PACKAGES=(
    cups
    cups-client
    system-config-printer
    x11vnc
    conky
    firefox-esr
    firefox-esr-l10n-pt-br
    gimp
    vlc
    evince
    file-roller
    gparted
    gnome-screenshot
    xbacklight
    pavucontrol
    pulseaudio
    pulseaudio-utils
    alsa-utils
    firmware-linux
    firmware-linux-nonfree
    intel-microcode
    amd64-microcode
    acpi
    acpid
    powermgmt-base
    upower
    colord
    geoclue-2.0
)

apt-get install -y "${EXTRA_PACKAGES[@]}"

# ============================================================
# Limpar cache do APT
# ============================================================
echo ">>> Limpando cache do APT..."
apt-get clean
apt-get autoremove -y

echo ">>> [03] Pacotes essenciais instalados!"
echo "============================================================"
