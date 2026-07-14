-- ============================================================================
-- SeederLinux Lite - Insercao dos Scripts Core
-- ============================================================================
-- Este arquivo contem os INSERTs para todos os scripts Core na tabela 'scripts'.
-- Deve ser executado apos o install/schema_completo.sql.
-- Os scripts Core sao os scripts base do provisionamento, com is_core=true.
-- Os placeholders {{VARIAVEL}} sao substituidos pelo sistema na geracao do bundle.
-- ============================================================================

BEGIN;

-- Limpar scripts Core existentes (se houver re-execucao)
DELETE FROM scripts WHERE is_core = true;

-- 01 - Configurar Repositorios APT
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configurar Repositorios APT',
    'core_repositories.sh',
    'Configura os repositorios APT do Debian 13 (Trixie) conforme o modo definido: PUBLIC, MIRROR, HYBRID ou CUSTOM.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_repositories.sh
# SeederLinux Lite - Configurar sources.list (APT)
# ============================================================================
# Configura os repositórios APT do Debian 13 (Trixie) conforme o modo
# definido: PUBLIC (repositórios oficiais), MIRROR (espelho local),
# HYBRID (espelho com fallback público) ou CUSTOM (URL personalizada).
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "01 - Configurar repositorios APT"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
REPOSITORY_MODE="{{REPOSITORY_MODE}}"
REPOSITORY_URL="{{REPOSITORY_URL}}"
REPOSITORY_FALLBACK="{{REPOSITORY_FALLBACK}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"

echo ">>> Modo de repositorio: $REPOSITORY_MODE"

# ============================================================
# Backup do sources.list original
# ============================================================
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)
    echo ">>> Backup do sources.list criado"
fi

# Remove arquivos .list antigos do sources.list.d para evitar conflitos
rm -f /etc/apt/sources.list.d/*.list.bak 2>/dev/null || true

# ============================================================
# Configuração conforme o modo
# ============================================================
case "$REPOSITORY_MODE" in
    PUBLIC)
        echo ">>> Configurando repositorios publicos (Debian 13 Trixie)"
        cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF
        ;;
    MIRROR)
        echo ">>> Configurando repositorio espelho: $REPOSITORY_URL"
        cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL trixie main contrib non-free non-free-firmware
deb $REPOSITORY_URL trixie-security main contrib non-free non-free-firmware
deb $REPOSITORY_URL trixie-updates main contrib non-free non-free-firmware
EOF
        ;;
    HYBRID)
        echo ">>> Configurando repositorio hibrido (espelho + fallback)"
        cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL trixie main contrib non-free non-free-firmware
deb $REPOSITORY_URL trixie-security main contrib non-free non-free-firmware
deb $REPOSITORY_URL trixie-updates main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK trixie main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK trixie-security main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK trixie-updates main contrib non-free non-free-firmware
EOF
        ;;
    CUSTOM)
        echo ">>> Configurando repositorio personalizado"
        if [ -n "$REPOSITORY_URL" ]; then
            cat > /etc/apt/sources.list <<EOF
$REPOSITORY_URL
EOF
        else
            echo ">>> ERRO: REPOSITORY_URL nao definido para modo CUSTOM"
            exit 1
        fi
        ;;
    *)
        echo ">>> ERRO: Modo de repositorio invalido: $REPOSITORY_MODE"
        exit 1
        ;;
esac

# ============================================================
# Atualizar índice de pacotes
# ============================================================
echo ">>> Atualizando apt-get update..."
apt-get update

echo ">>> [01] Repositorios configurados com sucesso!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    1,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 02 - Configurar DNS, NTP e Resolucao de Nomes
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configurar DNS, NTP e Resolucao de Nomes',
    'core_dns.sh',
    'Configura DNS temporario, /etc/resolv.conf, /etc/hosts e sincroniza NTP com o servidor definido.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_dns.sh
# SeederLinux Lite - DNS, NTP e resolucao de nomes
# ============================================================================
# Configura DNS temporario para permitir resolucao durante o provisionamento,
# ajusta /etc/resolv.conf, /etc/hosts e sincroniza NTP.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "02 - Configurar DNS, NTP e resolucao de nomes"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DOMINIO="{{DOMINIO}}"
DC_IP="{{DC_IP}}"
DC_IP_LIST="{{DC_IP_LIST}}"
DNS_PRIMARIO="{{DNS_PRIMARIO}}"
DNS_SECUNDARIO="{{DNS_SECUNDARIO}}"
DNS_INTERNET="{{DNS_INTERNET}}"
NTP_SERVER="{{NTP_SERVER}}"
OM_ACRONYM="{{OM_ACRONYM}}"

echo ">>> Dominio: $DOMINIO"
echo ">>> DNS primario: $DNS_PRIMARIO"
echo ">>> DNS secundario: $DNS_SECUNDARIO}"
echo ">>> NTP: $NTP_SERVER"

# ============================================================
# DNS temporário (para permitir apt-get durante o provisionamento)
# ============================================================
echo ">>> Configurando DNS temporario..."
if [ -n "$DNS_INTERNET" ] && [ "$DNS_INTERNET" != "" ]; then
    echo "nameserver $DNS_INTERNET" > /etc/resolv.conf
else
    echo "nameserver $DNS_PRIMARIO" > /etc/resolv.conf
    if [ -n "$DNS_SECUNDARIO" ] && [ "$DNS_SECUNDARIO" != "" ]; then
        echo "nameserver $DNS_SECUNDARIO" >> /etc/resolv.conf
    fi
fi
echo "search $DOMINIO" >> /etc/resolv.conf
echo ">>> DNS temporario configurado"

# ============================================================
# /etc/hosts - garantir resolucao do proprio host e do dominio
# ============================================================
echo ">>> Configurando /etc/hosts..."
HOSTNAME_SHORT=$(hostname)
HOSTNAME_FQDN="${HOSTNAME_SHORT}.${DOMINIO}"

cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d%H%M%S) 2>/dev/null || true

cat > /etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME_FQDN} ${HOSTNAME_SHORT}

# Controladores de dominio
EOF

# Adiciona todos os DCs no /etc/hosts
for DC in $DC_IP_LIST; do
    echo "$DC    ${DOMINIO%%.*}.$DOMINIO" >> /etc/hosts
done

echo ">>> /etc/hosts configurado"

# ============================================================
# NTP - sincronizar horario com o servidor
# ============================================================
echo ">>> Configurando NTP..."
if command -v timedatectl &> /dev/null; then
    timedatectl set-ntp true 2>/dev/null || true
fi

if [ -n "$NTP_SERVER" ] && [ "$NTP_SERVER" != "" ]; then
    # Tenta sincronizar imediatamente
    if command -v ntpdate &> /dev/null; then
        ntpdate "$NTP_SERVER" 2>/dev/null || true
    elif command -v chronyc &> /dev/null; then
        chronyc -a makestep 2>/dev/null || true
    fi

    # Configura NTP permanente
    if [ -d /etc/chrony ]; then
        cat > /etc/chrony/chrony.conf <<EOF
server $NTP_SERVER iburst
driftfile /var/lib/chrony/chrony.drift
makestep 1.0 3
rtcsync
EOF
        systemctl restart chrony 2>/dev/null || true
    elif [ -f /etc/ntp.conf ]; then
        cp /etc/ntp.conf /etc/ntp.conf.bak 2>/dev/null || true
        cat > /etc/ntp.conf <<EOF
server $NTP_SERVER iburst
driftfile /var/lib/ntp/ntp.drift
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
EOF
        systemctl restart ntp 2>/dev/null || true
    fi
    echo ">>> NTP configurado: $NTP_SERVER"
else
    echo ">>> NTP_SERVER nao definido, usando padrao do sistema"
fi

echo ">>> [02] DNS, NTP e resolucao de nomes configurados!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    2,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 03 - Instalar Pacotes Essenciais
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Instalar Pacotes Essenciais',
    'core_packages.sh',
    'Instala todos os pacotes necessarios: ferramentas de rede, autenticacao, ambiente grafico e utilitarios.',
    '#!/bin/bash
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
',
    true,  -- is_core
    true,  -- is_active
    3,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 04 - Ingresso no Active Directory
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Ingresso no Active Directory',
    'core_domain.sh',
    'Configura Kerberos, Samba, SSSD, PAM, NSS, sudo e mkhomedir para ingressar a estacao no dominio AD.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_domain.sh
# SeederLinux Lite - Ingresso no AD (SSSD/Winbind)
# ============================================================================
# Configura Kerberos, Samba, SSSD, PAM, NSS, sudo e mkhomedir para
# ingressar a estacao no dominio Active Directory.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "04 - Ingresso no Active Directory"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
DC_IP="{{DC_IP}}"
DC_IP_LIST="{{DC_IP_LIST}}"
OU_PADRAO="{{OU_PADRAO}}"
GRUPO_ADMIN="{{GRUPO_ADMIN}}"
GRUPO_ADMIN_AD="{{GRUPO_ADMIN_AD}}"
GRUPO_ADMIN_LINUX="{{GRUPO_ADMIN_LINUX}}"
GRUPO_DASTI="{{GRUPO_DASTI}}"
OFFLINE_AUTH_ENABLED="{{OFFLINE_AUTH_ENABLED}}"
OFFLINE_AUTH_DAYS="{{OFFLINE_AUTH_DAYS}}"
ADMIN_USERNAME="{{ADMIN_USERNAME}}"

echo ">>> Dominio: $DOMINIO"
echo ">>> NetBIOS: $DOMINIO_NETBIOS"
echo ">>> DC principal: $DC_IP"

# ============================================================
# Configurar Kerberos
# ============================================================
echo ">>> Configurando Kerberos..."
cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${DOMINIO_NETBIOS}
    dns_lookup_realm = false
    dns_lookup_kdc = true
    rdns = false
    ticket_lifetime = 24h
    forwardable = yes
    renew_lifetime = 7d

[realms]
    ${DOMINIO_NETBIOS} = {
        kdc = ${DC_IP}
        admin_server = ${DC_IP}
    }

[domain_realm]
    .${DOMINIO} = ${DOMINIO_NETBIOS}
    ${DOMINIO} = ${DOMINIO_NETBIOS}
EOF

echo ">>> Kerberos configurado"

# ============================================================
# Configurar Samba
# ============================================================
echo ">>> Configurando Samba..."
cat > /etc/samba/smb.conf <<EOF
[global]
    workgroup = ${DOMINIO_NETBIOS}
    realm = ${DOMINIO}
    security = ads
    dns forwarder = ${DC_IP}
    idmap config * : backend = tdb
    idmap config * : range = 3000-7999
    idmap config ${DOMINIO_NETBIOS} : backend = rid
    idmap config ${DOMINIO_NETBIOS} : range = 10000-999999
    template shell = /bin/bash
    template homedir = /home/%D/%U
    winbind use default domain = true
    winbind offline logon = false
    winbind nss info = rfc2307
    winbind enum users = no
    winbind enum groups = no
    load printers = no
    printing = bsd
    printcap name = /dev/null
    disable spoolss = yes
EOF

echo ">>> Samba configurado"

# ============================================================
# Ingressar no dominio
# ============================================================
echo ">>> Ingressando no dominio..."
# Obter ticket Kerberos (requer senha de admin do dominio)
echo ">>> Solicitando ticket Kerberos..."
kinit "${ADMIN_USERNAME}@${DOMINIO_NETBIOS}" || {
    echo ">>> AVISO: Falha ao obter ticket Kerberos."
    echo ">>> Verifique as credenciais e conectividade com o DC."
    exit 1
}

# Ingressar com net ads join
net ads join -U "${ADMIN_USERNAME}@${DOMINIO_NETBIOS}" \
    createcomputer="${OU_PADRAO}" || {
    echo ">>> ERRO: Falha ao ingressar no dominio"
    exit 1
}
echo ">>> Ingresso no dominio realizado"

# ============================================================
# Configurar SSSD
# ============================================================
echo ">>> Configurando SSSD..."
OFFLINE_CACHE=""
if [ "$OFFLINE_AUTH_ENABLED" = "true" ]; then
    DAYS="${OFFLINE_AUTH_DAYS:-3}"
    OFFLINE_CACHE="cache_credentials = true
    krb5_store_password_if_offline = true
    offline_credentials_expiration = ${DAYS}"
fi

cat > /etc/sssd/sssd.conf <<EOF
[sssd]
services = nss, pam, sudo
config_file_version = 2
domains = ${DOMINIO}

[domain/${DOMINIO}]
    id_provider = ad
    ad_domain = ${DOMINIO}
    ad_server = ${DC_IP}
    ad_hostname = $(hostname).${DOMINIO}
    ldap_id_mapping = true
    enumerate = false
    use_fully_qualified_names = false
    fallback_homedir = /home/%d/%u
    default_shell = /bin/bash
    ${OFFLINE_CACHE}
    dyndns_update = false
    sudo_provider = ad
    ldap_sudo_search_base = OU=sudoers,${OU_PADRAO}
EOF

chmod 600 /etc/sssd/sssd.conf
echo ">>> SSSD configurado"

# ============================================================
# Configurar NSS
# ============================================================
echo ">>> Configurando NSS..."
cat > /etc/nsswitch.conf <<EOF
passwd:     files systemd sss
shadow:     files sss
group:      files systemd sss
gshadow:    files

hosts:      files dns

services:   files sss
netgroup:   files sss
sudoers:    files sss

automount:  files sss
EOF

echo ">>> NSS configurado"

# ============================================================
# Configurar PAM (mkhomedir)
# ============================================================
echo ">>> Configurando PAM e mkhomedir..."
pam-auth-update --enable mkhomedir --force 2>/dev/null || true

# Garantir criacao automatica do home
if [ -f /etc/pam.d/common-session ]; then
    grep -q "pam_mkhomedir" /etc/pam.d/common-session || \
        echo "session required pam_mkhomedir.so skel=/etc/skel umask=0022" >> /etc/pam.d/common-session
fi

echo ">>> PAM configurado"

# ============================================================
# Configurar sudo para grupos do dominio
# ============================================================
echo ">>> Configurando sudo..."
SUDO_FILE="/etc/sudoers.d/seederlinux-domain"
cat > "$SUDO_FILE" <<EOF
# SeederLinux - Acesso sudo para grupos do dominio
%${GRUPO_ADMIN_AD}    ALL=(ALL:ALL) ALL
%${GRUPO_ADMIN_LINUX}  ALL=(ALL:ALL) ALL
EOF

if [ -n "$GRUPO_DASTI" ] && [ "$GRUPO_DASTI" != "" ]; then
    echo "%${GRUPO_DASTI}    ALL=(ALL:ALL) ALL" >> "$SUDO_FILE"
fi

chmod 440 "$SUDO_FILE"
visudo -cf "$SUDO_FILE" || {
    echo ">>> ERRO: sintaxe do sudoers invalida"
    exit 1
}

echo ">>> Sudo configurado"

# ============================================================
# Reiniciar servicos
# ============================================================
echo ">>> Reiniciando servicos..."
systemctl restart samba 2>/dev/null || true
systemctl restart sssd
systemctl enable sssd

echo ">>> [04] Ingresso no AD concluido!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    4,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 05 - Configurar Proxy do Sistema
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configurar Proxy do Sistema',
    'core_proxy.sh',
    'Configura proxy HTTP/HTTPS no nivel do sistema: /etc/environment, apt.conf.d e variaveis de ambiente.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_proxy.sh
# SeederLinux Lite - Proxy do sistema
# ============================================================================
# Configura o proxy HTTP/HTTPS no nivel do sistema (/etc/environment,
# /etc/apt/apt.conf.d) e em variaveis de ambiente globais.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "05 - Configurar proxy do sistema"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
PROXY_MODE="{{PROXY_MODE}}"
PROXY_HTTP="{{PROXY_HTTP}}"
PROXY_PORTA="{{PROXY_PORTA}}"
PROXY_URL="{{PROXY_URL}}"
PAC_URL="{{PAC_URL}}"
NO_PROXY="{{NO_PROXY}}"

echo ">>> Modo de proxy: $PROXY_MODE"

# ============================================================
# Configurar conforme o modo
# ============================================================
case "$PROXY_MODE" in
    NONE)
        echo ">>> Proxy desativado (NONE)"
        # Remover configuracoes de proxy existentes
        rm -f /etc/apt/apt.conf.d/95seederlinux-proxy 2>/dev/null || true
        # Limpar /etc/environment de entradas de proxy
        if [ -f /etc/environment ]; then
            sed -i ''/^http_proxy=/d; /^https_proxy=/d; /^ftp_proxy=/d; /^no_proxy=/d; /^HTTP_PROXY=/d; /^HTTPS_PROXY=/d; /^FTP_PROXY=/d; /^NO_PROXY=/d'' /etc/environment || true
        fi
        echo ">>> Configuracoes de proxy removidas"
        ;;

    MANUAL)
        echo ">>> Configurando proxy manual: ${PROXY_HTTP}:${PROXY_PORTA}"

        # Construir URL do proxy
        if [ -n "$PROXY_URL" ] && [ "$PROXY_URL" != "" ]; then
            PROXY_FULL_URL="$PROXY_URL"
        else
            PROXY_FULL_URL="http://${PROXY_HTTP}:${PROXY_PORTA}"
        fi

        # Configurar APT
        cat > /etc/apt/apt.conf.d/95seederlinux-proxy <<EOF
Acquire::http::Proxy "${PROXY_FULL_URL}";
Acquire::https::Proxy "${PROXY_FULL_URL}";
Acquire::ftp::Proxy "${PROXY_FULL_URL}";
EOF

        # Configurar /etc/environment
        if [ -f /etc/environment ]; then
            # Remover entradas antigas
            sed -i ''/^http_proxy=/d; /^https_proxy=/d; /^ftp_proxy=/d; /^no_proxy=/d; /^HTTP_PROXY=/d; /^HTTPS_PROXY=/d; /^FTP_PROXY=/d; /^NO_PROXY=/d'' /etc/environment || true
        fi

        cat >> /etc/environment <<EOF
http_proxy="${PROXY_FULL_URL}"
https_proxy="${PROXY_FULL_URL}"
ftp_proxy="${PROXY_FULL_URL}"
HTTP_PROXY="${PROXY_FULL_URL}"
HTTPS_PROXY="${PROXY_FULL_URL}"
FTP_PROXY="${PROXY_FULL_URL}"
EOF

        if [ -n "$NO_PROXY" ] && [ "$NO_PROXY" != "" ]; then
            echo "no_proxy=\"${NO_PROXY}\"" >> /etc/environment
            echo "NO_PROXY=\"${NO_PROXY}\"" >> /etc/environment
        fi

        echo ">>> Proxy manual configurado"
        ;;

    PAC)
        echo ">>> Configurando proxy via PAC: ${PAC_URL}"

        if [ -z "$PAC_URL" ] || [ "$PAC_URL" = "" ]; then
            echo ">>> ERRO: PAC_URL nao definido para modo PAC"
            exit 1
        fi

        # Configurar APT com PAC (apt suporta PAC via auto)
        cat > /etc/apt/apt.conf.d/95seederlinux-proxy <<EOF
Acquire::http::Proxy::Pac "${PAC_URL}";
Acquire::https::Proxy::Pac "${PAC_URL}";
EOF

        # Para navegadores, o PAC sera configurado no core_browser.sh
        echo "PAC_URL=${PAC_URL}" > /etc/seederlinux/pac_url.conf 2>/dev/null || {
            mkdir -p /etc/seederlinux
            echo "PAC_URL=${PAC_URL}" > /etc/seederlinux/pac_url.conf
        }

        echo ">>> Proxy via PAC configurado"
        ;;

    *)
        echo ">>> ERRO: Modo de proxy invalido: $PROXY_MODE"
        exit 1
        ;;
esac

echo ">>> [05] Proxy do sistema configurado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    5,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 06 - Politicas de Navegadores
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Politicas de Navegadores',
    'core_browser.sh',
    'Configura politicas corporativas para Firefox ESR, Google Chrome e Chromium via arquivos JSON de policies.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_browser.sh
# SeederLinux Lite - Politicas Firefox/Chrome
# ============================================================================
# Configura politicas corporativas para Firefox ESR, Google Chrome e Chromium
# via arquivos de policies (JSON) no sistema.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "06 - Configurar politicas de navegadores"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
HOMEPAGE="{{HOMEPAGE}}"
PROXY_MODE="{{PROXY_MODE}}"
PROXY_HTTP="{{PROXY_HTTP}}"
PROXY_PORTA="{{PROXY_PORTA}}"
PAC_URL="{{PAC_URL}}"
NO_PROXY="{{NO_PROXY}}"
DOMINIO="{{DOMINIO}}"
OM_ACRONYM="{{OM_ACRONYM}}"
CERTIFICATE_BUNDLE="{{CERTIFICATE_BUNDLE}}"

echo ">>> Homepage: $HOMEPAGE"
echo ">>> Modo de proxy: $PROXY_MODE"

# ============================================================
# Firefox ESR - Politicas (policies.json)
# ============================================================
echo ">>> Configurando politicas do Firefox ESR..."
mkdir -p /usr/lib/firefox-esr/distribution

cat > /usr/lib/firefox-esr/distribution/policies.json <<EOF
{
    "policies": {
        "DisableTelemetry": true,
        "DisableFirefoxStudies": true,
        "DisablePocket": true,
        "DisableDeveloperTools": false,
        "BlockAboutConfig": false,
        "Homepage": {
            "URL": "${HOMEPAGE}",
            "Locked": true,
            "StartPage": "homepage"
        },
        "HomepageURL": "${HOMEPAGE}",
        "SearchBar": "unified",
        "SearchEngines": {
            "Add": [
                {
                    "Name": "${OM_ACRONYM}",
                    "URL": "${HOMEPAGE}",
                    "Method": "GET"
                }
            ]
        },
        "Proxy": {
            "Mode": "system",
            "Locked": true
        },
        "Certificates": {
            "ImportEnterpriseRoots": true
        },
        "ExtensionSettings": {
            "*": {
                "installation_mode": "allowed"
            }
        },
        "DisableSetDesktopBackground": false,
        "DontCheckDefaultBrowser": true,
        "PrimaryPassword": false,
        "OfferToSaveLogins": false,
        "PasswordManagerEnabled": false,
        "SanitizeOnShutdown": {
            "Cache": true,
            "Cookies": false,
            "Downloads": false,
            "FormData": true,
            "History": false,
            "Sessions": false,
            "SiteSettings": false,
            "OfflineApps": false
        }
    }
}
EOF

echo ">>> Politicas do Firefox configuradas"

# ============================================================
# Firefox ESR - autoconfig (para proxy PAC)
# ============================================================
if [ "$PROXY_MODE" = "PAC" ]; then
    echo ">>> Configurando PAC no Firefox..."
    mkdir -p /usr/lib/firefox-esr/defaults/pref
    cat > /usr/lib/firefox-esr/defaults/pref/autoconfig.js <<EOF
pref("general.config.filename", "seederlinux.cfg");
pref("general.config.obscure_value", 0);
EOF

    cat > /usr/lib/firefox-esr/seederlinux.cfg <<EOF
lockPref("network.proxy.type", 2);
lockPref("network.proxy.autoconfig_url", "${PAC_URL}");
lockPref("network.proxy.no_proxies_on", "${NO_PROXY}");
EOF
    echo ">>> PAC configurado no Firefox"
elif [ "$PROXY_MODE" = "MANUAL" ]; then
    echo ">>> Configurando proxy manual no Firefox..."
    mkdir -p /usr/lib/firefox-esr/defaults/pref
    cat > /usr/lib/firefox-esr/defaults/pref/autoconfig.js <<EOF
pref("general.config.filename", "seederlinux.cfg");
pref("general.config.obscure_value", 0);
EOF

    cat > /usr/lib/firefox-esr/seederlinux.cfg <<EOF
lockPref("network.proxy.type", 1);
lockPref("network.proxy.http", "${PROXY_HTTP}");
lockPref("network.proxy.http_port", ${PROXY_PORTA});
lockPref("network.proxy.https", "${PROXY_HTTP}");
lockPref("network.proxy.https_port", ${PROXY_PORTA});
lockPref("network.proxy.no_proxies_on", "${NO_PROXY}");
EOF
    echo ">>> Proxy manual configurado no Firefox"
fi

# ============================================================
# Google Chrome - Politicas
# ============================================================
echo ">>> Configurando politicas do Google Chrome..."
mkdir -p /etc/opt/chrome/policies/managed
mkdir -p /etc/opt/chrome/policies/recommended

# Proxy config para Chrome
case "$PROXY_MODE" in
    NONE)
        CHROME_PROXY_MODE="direct"
        ;;
    MANUAL)
        CHROME_PROXY_MODE="fixed_servers"
        CHROME_PROXY_SERVERS="http=${PROXY_HTTP}:${PROXY_PORTA};https=${PROXY_HTTP}:${PROXY_PORTA}"
        ;;
    PAC)
        CHROME_PROXY_MODE="pac_script"
        CHROME_PROXY_PAC_URL="$PAC_URL"
        ;;
    *)
        CHROME_PROXY_MODE="system"
        ;;
esac

# Construir JSON de proxy
PROXY_JSON=""
if [ "$CHROME_PROXY_MODE" = "fixed_servers" ]; then
    PROXY_JSON=", \"ProxyMode\": \"${CHROME_PROXY_MODE}\", \"ProxyServer\": \"${CHROME_PROXY_SERVERS}\""
elif [ "$CHROME_PROXY_MODE" = "pac_script" ]; then
    PROXY_JSON=", \"ProxyMode\": \"${CHROME_PROXY_MODE}\", \"ProxyPacUrl\": \"${CHROME_PROXY_PAC_URL}\""
else
    PROXY_JSON=", \"ProxyMode\": \"${CHROME_PROXY_MODE}\""
fi

cat > /etc/opt/chrome/policies/managed/seederlinux.json <<EOF
{
    "HomepageLocation": "${HOMEPAGE}",
    "HomepageIsNewTabPage": false,
    "RestoreOnStartup": 1,
    "RestoreOnStartupURLs": ["${HOMEPAGE}"],
    "BrowserSignin": 0,
    "SyncDisabled": true,
    "BlockThirdPartyCookies": true,
    "BackgroundModeEnabled": false,
    "TelemetryReportingEnabled": false,
    "UrlKeyboardsEnabled": false${PROXY_JSON},
    "DefaultCookiesSetting": 1,
    "AutoSelectCertificateForUrls": ["{\"pattern\":\"https://*\",\"filter\":{}}"],
    "ChromeCertProtectorEnabled": false
}
EOF

echo ">>> Politicas do Chrome configuradas"

# ============================================================
# Chromium - Politicas (mesmas do Chrome)
# ============================================================
echo ">>> Configurando politicas do Chromium..."
mkdir -p /etc/chromium/policies/managed
mkdir -p /etc/chromium/policies/recommended

cp /etc/opt/chrome/policies/managed/seederlinux.json \
   /etc/chromium/policies/managed/seederlinux.json 2>/dev/null || true

echo ">>> Politicas do Chromium configuradas"

echo ">>> [06] Politicas de navegadores configuradas!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    6,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 07 - OCS Inventory Agent
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'OCS Inventory Agent',
    'core_inventory.sh',
    'Instala e configura o agente do OCS Inventory para coleta de inventario automatica da estacao.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_inventory.sh
# SeederLinux Lite - OCS Inventory Agent
# ============================================================================
# Instala e configura o agente do OCS Inventory para coleta de inventario
# automatica da estacao.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "07 - Configurar OCS Inventory Agent"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
INVENTORY_ENABLED="{{INVENTORY_ENABLED}}"
OCS_SERVER="{{OCS_SERVER}}"
OCS_TAG="{{OCS_TAG}}"
GLPI_SERVER="{{GLPI_SERVER}}"

echo ">>> Inventario habilitado: $INVENTORY_ENABLED"

# ============================================================
# Verificar se o inventario esta habilitado
# ============================================================
if [ "$INVENTORY_ENABLED" != "true" ]; then
    echo ">>> Inventario desativado. Pulando configuracao."
    echo ">>> [07] OCS Inventory desativado."
    echo "============================================================"
    exit 0
fi

if [ -z "$OCS_SERVER" ] || [ "$OCS_SERVER" = "" ]; then
    echo ">>> AVISO: OCS_SERVER nao definido. Pulando configuracao."
    echo ">>> [07] OCS Inventory nao configurado (servidor ausente)."
    echo "============================================================"
    exit 0
fi

echo ">>> Servidor OCS: $OCS_SERVER"
echo ">>> Tag OCS: $OCS_TAG"

# ============================================================
# Instalar pacotes do OCS Inventory
# ============================================================
echo ">>> Instalando agente OCS Inventory..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y ocsinventory-agent dmidecode

# ============================================================
# Configurar agente OCS
# ============================================================
echo ">>> Configurando agente OCS..."
mkdir -p /etc/ocsinventory-agent

cat > /etc/ocsinventory-agent/ocsinventory-agent.cfg <<EOF
# Configuracao do OCS Inventory Agent - SeederLinux
server = ${OCS_SERVER}
tag = ${OCS_TAG}
basepath = /var/lib/ocsinventory-agent
debug = 0
local = no
nosoftware = 0
verbose = 0
EOF

# Arquivo de configuracao para o modulo Perl
OCS_URL="http://${OCS_SERVER}/ocsinventory"
cat > /etc/ocsinventory-agent/modules.conf 2>/dev/null <<EOF
# Modulos do OCS Inventory Agent
OCS_MODE = HTTP
OCS_SERVER = ${OCS_SERVER}
OCS_TAG = ${OCS_TAG}
EOF

# Configurar cron para execucao periodica
echo ">>> Configurando cron do OCS..."
cat > /etc/cron.d/ocsinventory-agent <<EOF
# OCS Inventory Agent - SeederLinux
# Executa a cada 4 horas
0 */4 * * * root /usr/bin/ocsinventory-agent --server=${OCS_SERVER} --tag="${OCS_TAG}" --lazy 2>/dev/null
EOF
chmod 644 /etc/cron.d/ocsinventory-agent

# ============================================================
# Configurar GLPI (se disponivel)
# ============================================================
if [ -n "$GLPI_SERVER" ] && [ "$GLPI_SERVER" != "" ]; then
    echo ">>> Configurando integracao GLPI..."
    mkdir -p /etc/glpi-agent

    cat > /etc/glpi-agent/agent.cfg <<EOF
# Configuracao do GLPI Agent - SeederLinux
server = ${GLPI_SERVER}
tag = ${OCS_TAG}
EOF

    # Instalar GLPI Agent se disponivel
    apt-get install -y glpi-agent 2>/dev/null || {
        echo ">>> GLPI Agent nao disponivel nos repositorios. Pulando."
    }
fi

# ============================================================
# Execucao inicial do inventario
# ============================================================
echo ">>> Executando coleta inicial de inventario..."
ocsinventory-agent --server="$OCS_SERVER" --tag="$OCS_TAG" --lazy 2>/dev/null || {
    echo ">>> AVISO: Falha na coleta inicial. Sera refeito via cron."
}

echo ">>> [07] OCS Inventory configurado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    7,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 08 - CUPS e Impressoras
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'CUPS e Impressoras',
    'core_printers.sh',
    'Configura o CUPS e instala as impressoras compartilhadas via servidor de impressao.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_printers.sh
# SeederLinux Lite - CUPS e impressoras
# ============================================================================
# Configura o CUPS e instala as impressoras compartilhadas via servidor
# de impressao.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "08 - Configurar CUPS e impressoras"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
PRINT_SERVER="{{PRINT_SERVER}}"
DEFAULT_PRINTER="{{DEFAULT_PRINTER}}"
PRINTERS="{{PRINTERS}}"
DOMINIO="{{DOMINIO}}"

echo ">>> Servidor de impressao: $PRINT_SERVER"
echo ">>> Impressora padrao: $DEFAULT_PRINTER"

# ============================================================
# Verificar se ha servidor de impressao
# ============================================================
if [ -z "$PRINT_SERVER" ] || [ "$PRINT_SERVER" = "" ]; then
    echo ">>> AVISO: PRINT_SERVER nao definido. Pulando configuracao."
    echo ">>> [08] Impressoras nao configuradas (servidor ausente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Configurar CUPS
# ============================================================
echo ">>> Configurando CUPS..."
export DEBIAN_FRONTEND=noninteractive

# Garantir que o CUPS esteja instalado
apt-get install -y cups cups-client system-config-printer

# Habilitar e iniciar CUPS
systemctl enable cups
systemctl start cups

# Permitir administracao remota e compartilhamento
cupsctl --remote-admin --remote-any --share-printers 2>/dev/null || true

# Configurar cupsd.conf
cat > /etc/cups/cupsd.conf <<EOF
# Configuracao CUPS - SeederLinux
Browsing On
BrowseLocalProtocols dnssd
DefaultAuthType Basic
WebInterface Yes

Listen localhost:631
Listen /run/cups/cups.sock

<Location />
    Order allow,deny
    Allow all
</Location>

<Location /admin>
    Order allow,deny
    Allow all
</Location>

<Location /admin/conf>
    AuthType Default
    Require user @SYSTEM
    Order allow,deny
    Allow all
</Location>
EOF

systemctl restart cups

# ============================================================
# Configurar impressoras via servidor CUPS remoto
# ============================================================
echo ">>> Configurando impressoras via servidor remoto..."

# Criar arquivo de configuracao client.conf do CUPS
cat > /etc/cups/client.conf <<EOF
# Cliente CUPS - SeederLinux
ServerName ${PRINT_SERVER}
EOF

# ============================================================
# Instalar cada impressora listada
# ============================================================
if [ -n "$PRINTERS" ] && [ "$PRINTERS" != "" ]; then
    echo ">>> Instalando impressoras listadas..."
    for PRINTER in $PRINTERS; do
        echo ">>> Configurando impressora: $PRINTER"
        # Adicionar impressora via lpadmin (IPP via servidor)
        lpadmin -p "$PRINTER" -E -v "ipp://${PRINT_SERVER}/printers/${PRINTER}" \
            -m everywhere 2>/dev/null || {
            echo ">>> AVISO: Falha ao adicionar impressora $PRINTER"
        }
    done
else
    echo ">>> Nenhuma impressora listada. Usando descoberta automatica."
    # Descoberta automatica via servidor remoto
    lpinfo -h "$PRINT_SERVER" -v 2>/dev/null | grep ipp | while read -r line; do
        PRINTER_URI=$(echo "$line" | awk ''{print $2}'')
        PRINTER_NAME=$(basename "$PRINTER_URI")
        echo ">>> Impressora encontrada: $PRINTER_NAME"
        lpadmin -p "$PRINTER_NAME" -E -v "$PRINTER_URI" -m everywhere 2>/dev/null || true
    done
fi

# ============================================================
# Definir impressora padrao
# ============================================================
if [ -n "$DEFAULT_PRINTER" ] && [ "$DEFAULT_PRINTER" != "" ]; then
    echo ">>> Definindo impressora padrao: $DEFAULT_PRINTER"
    lpadmin -d "$DEFAULT_PRINTER" 2>/dev/null || {
        echo ">>> AVISO: Falha ao definir impressora padrao"
    }
fi

# ============================================================
# Reiniciar CUPS para aplicar
# ============================================================
systemctl restart cups

echo ">>> [08] CUPS e impressoras configurados!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    8,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 09 - x11vnc
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'x11vnc',
    'core_vnc.sh',
    'Instala e configura o x11vnc para suporte remoto, incluindo servico systemd e senha de acesso.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_vnc.sh
# SeederLinux Lite - x11vnc
# ============================================================================
# Instala e configura o x11vnc para suporte remoto, incluindo servico
# systemd e senha de acesso.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "09 - Configurar x11vnc"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
VNC_ENABLED="{{VNC_ENABLED}}"
VNC_PASSWORD="{{VNC_PASSWORD}}"
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"

echo ">>> VNC habilitado: $VNC_ENABLED"

# ============================================================
# Verificar se VNC esta habilitado
# ============================================================
if [ "$VNC_ENABLED" != "true" ]; then
    echo ">>> VNC desativado. Pulando configuracao."
    echo ">>> [09] x11vnc desativado."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Instalar x11vnc
# ============================================================
echo ">>> Instalando x11vnc..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y x11vnc

# ============================================================
# Configurar senha do VNC
# ============================================================
echo ">>> Configurando senha do VNC..."
mkdir -p /etc/x11vnc

if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "" ]; then
    x11vnc -storepasswd "$VNC_PASSWORD" /etc/x11vnc/vncpasswd
    chmod 600 /etc/x11vnc/vncpasswd
    echo ">>> Senha VNC configurada"
else
    echo ">>> AVISO: VNC_PASSWORD nao definido. Gerando senha aleatoria."
    RANDOM_PASS=$(openssl rand -base64 12)
    x11vnc -storepasswd "$RANDOM_PASS" /etc/x11vnc/vncpasswd
    chmod 600 /etc/x11vnc/vncpasswd
    echo ">>> Senha aleatoria gerada (verificar /etc/x11vnc/vncpasswd)"
fi

# ============================================================
# Criar servico systemd para x11vnc
# ============================================================
echo ">>> Criando servico systemd x11vnc..."

# Determinar o display e o auth file conforme o display manager
case "$DISPLAY_MANAGER" in
    lightdm)
        VNC_DISPLAY=":0"
        VNC_AUTH="/var/run/lightdm/root/:0"
        ;;
    gdm3)
        VNC_DISPLAY=":0"
        VNC_AUTH="/run/user/0/gdm/Xauthority"
        ;;
    sddm)
        VNC_DISPLAY=":0"
        VNC_AUTH="/var/run/sddm/:0"
        ;;
    *)
        VNC_DISPLAY=":0"
        VNC_AUTH="/tmp/.X0-lock"
        ;;
esac

cat > /etc/systemd/system/x11vnc.service <<EOF
[Unit]
Description=x11vnc Server - SeederLinux
After=display-manager.service
Requires=display-manager.service

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -display ${VNC_DISPLAY} -auth ${VNC_AUTH} -forever -loop -noxdamage -repeat -rfbauth /etc/x11vnc/vncpasswd -rfbport 5900 -shared -bg -o /var/log/x11vnc.log
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable x11vnc.service
systemctl start x11vnc.service 2>/dev/null || {
    echo ">>> AVISO: Nao foi possivel iniciar x11vnc agora."
    echo ">>> O servico sera iniciado apos o display manager."
}

echo ">>> [09] x11vnc configurado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    9,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 10 - Conky
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Conky',
    'core_conky.sh',
    'Instala e configura o Conky para exibicao de informacoes do sistema no desktop com perfil personalizavel.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_conky.sh
# SeederLinux Lite - Conky
# ============================================================================
# Instala e configura o Conky para exibicao de informacoes do sistema
# no desktop, com perfil personalizavel.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "10 - Configurar Conky"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
CONKY_PROFILE="{{CONKY_PROFILE}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
OM_ACRONYM="{{OM_ACRONYM}}"
OM_NAME="{{OM_NAME}}"

echo ">>> Perfil Conky: $CONKY_PROFILE"
echo ">>> Ambiente: $DESKTOP_ENV"

# ============================================================
# Instalar Conky
# ============================================================
echo ">>> Instalando Conky..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y conky conky-all

# ============================================================
# Criar diretorio de configuracao global
# ============================================================
mkdir -p /etc/seederlinux/conky

# ============================================================
# Gerar configuracao do Conky
# ============================================================
echo ">>> Gerando configuracao do Conky..."

if [ -n "$CONKY_PROFILE" ] && [ "$CONKY_PROFILE" != "" ]; then
    # Baixar perfil personalizado se disponivel
    echo ">>> Usando perfil personalizado: $CONKY_PROFILE"
    cat > /etc/seederlinux/conky/conky.conf <<EOF
# Configuracao Conky - SeederLinux
# Perfil: ${CONKY_PROFILE}

conky.config = {
    alignment = ''top_right'',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = ''white'',
    default_outline_color = ''grey'',
    default_shade_color = ''grey'',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    extra_newline = false,
    font = ''DejaVu Sans Mono:size=10'',
    gap_x = 10,
    gap_y = 30,
    minimum_height = 5,
    minimum_width = 200,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_class = ''Conky'',
    own_window_type = ''desktop'',
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    own_window_transparent = true,
    own_window_hints = ''undecorated,below,sticky,skip_taskbar,skip_pager'',
    show_graph_range = false,
    show_graph_scale = false,
    stippled_borders = 0,
    update_interval = 2.0,
    uppercase = false,
    use_spacer = ''none'',
    use_xft = true,
    xinerama_head = 1,
}

conky.text = [[
\${color white}${OM_ACRONYM} - ${OM_NAME}
\${color white}\${hr}
\${color white}Sistema: \${color grey}\${exec uname -o}
\${color white}Kernel:  \${color grey}\${exec uname -r}
\${color white}Host:    \${color grey}\${nodename}
\${color white}Uptime:  \${color grey}\${uptime}
\${color white}\${hr}
\${color white}CPU: \${color grey}\${cpu}% \${cpubar 4}
\${color white}RAM: \${color grey}\${mem}/\${memmax} \${membar 4}
\${color white}SWAP: \${color grey}\${swap}/\${swapmax} \${swapbar 4}
\${color white}\${hr}
\${color white}IP:   \${color grey}\${addr}
\${color white}Down: \${color grey}\${downspeed} \${downspeedgraph 10,80}
\${color white}Up:   \${color grey}\${upspeed} \${upspeedgraph 10,80}
\${color white}\${hr}
\${color white}Filesystems:
\${color grey}\${fs_used /}/\${fs_size /} \${fs_bar 6 /}
]]
EOF
else
    # Perfil padrao
    echo ">>> Usando perfil padrao"
    cat > /etc/seederlinux/conky/conky.conf <<EOF
# Configuracao Conky - SeederLinux (Padrao)

conky.config = {
    alignment = ''top_right'',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = ''white'',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    font = ''DejaVu Sans Mono:size=10'',
    gap_x = 10,
    gap_y = 30,
    minimum_width = 200,
    net_avg_samples = 2,
    no_buffers = true,
    own_window = true,
    own_window_class = ''Conky'',
    own_window_type = ''desktop'',
    own_window_transparent = true,
    own_window_hints = ''undecorated,below,sticky,skip_taskbar,skip_pager'',
    update_interval = 2.0,
    use_xft = true,
}

conky.text = [[
\${color white}${OM_ACRONYM}
\${color white}\${hr}
\${color white}CPU: \${color grey}\${cpu}% \${cpubar 4}
\${color white}RAM: \${color grey}\${mem}/\${memmax} \${membar 4}
\${color white}Uptime: \${color grey}\${uptime}
\${color white}IP: \${color grey}\${addr}
]]
EOF
fi

# ============================================================
# Criar script de inicializacao do Conky
# ============================================================
echo ">>> Criando script de inicializacao..."
cat > /usr/local/bin/seederlinux-conky <<''SCRIPT''
#!/bin/bash
# Inicia o Conky com a configuracao do SeederLinux
CONKY_CONF="/etc/seederlinux/conky/conky.conf"

# Aguardar o ambiente grafico estar pronto
sleep 5

if [ -f "$CONKY_CONF" ]; then
    killall conky 2>/dev/null || true
    conky -c "$CONKY_CONF" &
else
    echo "Configuracao do Conky nao encontrada: $CONKY_CONF"
fi
SCRIPT

chmod +x /usr/local/bin/seederlinux-conky

# ============================================================
# Adicionar Conky ao autostart conforme o DE
# ============================================================
echo ">>> Configurando autostart do Conky para: $DESKTOP_ENV"

case "$DESKTOP_ENV" in
    cinnamon)
        mkdir -p /etc/xdg/autostart
        cat > /etc/xdg/autostart/seederlinux-conky.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Conky (SeederLinux)
Exec=/usr/local/bin/seederlinux-conky
Terminal=false
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF
        ;;
    mate|xfce|lxde)
        mkdir -p /etc/xdg/autostart
        cat > /etc/xdg/autostart/seederlinux-conky.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Conky (SeederLinux)
Exec=/usr/local/bin/seederlinux-conky
Terminal=false
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF
        ;;
    gnome)
        mkdir -p /etc/xdg/autostart
        cat > /etc/xdg/autostart/seederlinux-conky.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Conky (SeederLinux)
Exec=/usr/local/bin/seederlinux-conky
Terminal=false
X-GNOME-Autostart-enabled=true
NoDisplay=false
EOF
        ;;
    kde)
        mkdir -p /usr/share/autostart
        cat > /usr/share/autostart/seederlinux-conky.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Conky (SeederLinux)
Exec=/usr/local/bin/seederlinux-conky
Terminal=false
X-KDE-autostart-enabled=true
EOF
        ;;
esac

echo ">>> [10] Conky configurado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    10,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 11 - Aplicativos (OnlyOffice, Chrome, Firefox ESR)
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Aplicativos (OnlyOffice, Chrome, Firefox ESR)',
    'core_apps.sh',
    'Instala OnlyOffice Desktop Editors, Google Chrome estavel e Firefox ESR.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_apps.sh
# SeederLinux Lite - OnlyOffice, Chrome, Firefox ESR
# ============================================================================
# Instala aplicativos adicionais: OnlyOffice Desktop Editors, Google Chrome
# estavel e Firefox ESR.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "11 - Instalar aplicativos (OnlyOffice, Chrome, Firefox ESR)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
INSTALL_APPS="{{INSTALL_APPS}}"
BASE_URL="{{BASE_URL}}"
PROXY_MODE="{{PROXY_MODE}}"
PROXY_HTTP="{{PROXY_HTTP}}"
PROXY_PORTA="{{PROXY_PORTA}}"

echo ">>> Instalar apps: $INSTALL_APPS"

# ============================================================
# Verificar se a instalacao esta habilitada
# ============================================================
if [ "$INSTALL_APPS" != "true" ]; then
    echo ">>> Instalacao de apps desativada. Pulando."
    echo ">>> [11] Aplicativos nao instalados (desativado)."
    echo "============================================================"
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive

# Configurar proxy para downloads se necessario
if [ "$PROXY_MODE" = "MANUAL" ] && [ -n "$PROXY_HTTP" ] && [ "$PROXY_HTTP" != "" ]; then
    export http_proxy="http://${PROXY_HTTP}:${PROXY_PORTA}"
    export https_proxy="http://${PROXY_HTTP}:${PROXY_PORTA}"
fi

# ============================================================
# Firefox ESR
# ============================================================
echo ">>> Instalando Firefox ESR..."
apt-get install -y firefox-esr firefox-esr-l10n-pt-br

# ============================================================
# Google Chrome
# ============================================================
echo ">>> Instalando Google Chrome..."
CHROME_DEB="/tmp/google-chrome-stable.deb"

# Baixar Chrome
if wget -q -O "$CHROME_DEB" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"; then
    apt-get install -y "$CHROME_DEB" || {
        echo ">>> AVISO: Falha ao instalar Google Chrome. Tentando dependencias..."
        apt-get install -y -f
        apt-get install -y "$CHROME_DEB" || {
            echo ">>> AVISO: Google Chrome nao instalado."
        }
    }
    rm -f "$CHROME_DEB"
else
    echo ">>> AVISO: Nao foi possivel baixar Google Chrome."
    echo ">>> Verifique conectividade e configuracao de proxy."
fi

# ============================================================
# OnlyOffice Desktop Editors
# ============================================================
echo ">>> Instalando OnlyOffice Desktop Editors..."

# Metodo 1: Via repositorio APT oficial
ONLYOFFICE_KEY="/tmp/onlyoffice-key.asc"
ONLYOFFICE_REPO_LIST="/etc/apt/sources.list.d/onlyoffice.list"

# Baixar e adicionar chave GPG
if wget -q -O "$ONLYOFFICE_KEY" "https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE"; then
    gpg --dearmor < "$ONLYOFFICE_KEY" > /usr/share/keyrings/onlyoffice-keyring.gpg 2>/dev/null || \
        apt-key add "$ONLYOFFICE_KEY" 2>/dev/null || true

    cat > "$ONLYOFFICE_REPO_LIST" <<EOF
deb [signed-by=/usr/share/keyrings/onlyoffice-keyring.gpg] https://download.onlyoffice.com/repo/debian squeeze main
EOF

    apt-get update
    apt-get install -y onlyoffice-desktopeditors || {
        echo ">>> AVISO: Falha ao instalar OnlyOffice via repositorio."
        echo ">>> Tentando download direto..."

        # Metodo 2: Download direto do .deb
        ONLYOFFICE_DEB="/tmp/onlyoffice-desktopeditors.deb"
        if wget -q -O "$ONLYOFFICE_DEB" "https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors_amd64.deb"; then
            apt-get install -y "$ONLYOFFICE_DEB" || {
                echo ">>> AVISO: Falha ao instalar OnlyOffice via .deb direto."
            }
            rm -f "$ONLYOFFICE_DEB"
        else
            echo ">>> AVISO: Nao foi possivel baixar OnlyOffice."
        fi
    }
    rm -f "$ONLYOFFICE_KEY"
else
    echo ">>> AVISO: Nao foi possivel obter chave do OnlyOffice."
    echo ">>> Tentando instalar via repositorio Debian..."

    apt-get install -y onlyoffice-desktopeditors 2>/dev/null || {
        echo ">>> AVISO: OnlyOffice nao disponivel. Instalacao ignorada."
    }
fi

# ============================================================
# Verificar instalacoes
# ============================================================
echo ">>> Verificando instalacoes..."
command -v firefox-esr &> /dev/null && echo ">>> Firefox ESR: OK" || echo ">>> Firefox ESR: NAO INSTALADO"
command -v google-chrome &> /dev/null && echo ">>> Google Chrome: OK" || echo ">>> Google Chrome: NAO INSTALADO"
command -v onlyoffice-desktopeditors &> /dev/null && echo ">>> OnlyOffice: OK" || echo ">>> OnlyOffice: NAO INSTALADO"

echo ">>> [11] Aplicativos instalados!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    11,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 12 - Sistemas Legados (Java 8, Firefox 52.7)
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Sistemas Legados (Java 8, Firefox 52.7)',
    'core_legados.sh',
    'Instala Java 8 e Firefox 52.7 ESR para compatibilidade com sistemas legados.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_legados.sh
# SeederLinux Lite - Java 8, Firefox 52.7 ESR (sistemas legados)
# ============================================================================
# Instala Java 8 (OpenJDK ou Oracle) e Firefox 52.7 ESR para compatibilidade
# com sistemas legados (applets Java, sistemas antigos da intranet).
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "12 - Instalar sistemas legados (Java 8, Firefox 52.7)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
INSTALL_LEGADOS="{{INSTALL_LEGADOS}}"
BASE_URL="{{BASE_URL}}"
PROXY_MODE="{{PROXY_MODE}}"
PROXY_HTTP="{{PROXY_HTTP}}"
PROXY_PORTA="{{PROXY_PORTA}}"

echo ">>> Instalar sistemas legados: $INSTALL_LEGADOS"

# ============================================================
# Verificar se a instalacao esta habilitada
# ============================================================
if [ "$INSTALL_LEGADOS" != "true" ]; then
    echo ">>> Sistemas legados desativados. Pulando."
    echo ">>> [12] Sistemas legados nao instalados (desativado)."
    echo "============================================================"
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive

# Configurar proxy para downloads
if [ "$PROXY_MODE" = "MANUAL" ] && [ -n "$PROXY_HTTP" ] && [ "$PROXY_HTTP" != "" ]; then
    export http_proxy="http://${PROXY_HTTP}:${PROXY_PORTA}"
    export https_proxy="http://${PROXY_HTTP}:${PROXY_PORTA}"
fi

# ============================================================
# Java 8 (OpenJDK 8)
# ============================================================
echo ">>> Instalando Java 8 (OpenJDK 8)..."

# Tentar instalar via repositorio
if apt-get install -y openjdk-8-jre 2>/dev/null; then
    echo ">>> OpenJDK 8 instalado via repositorio"
else
    echo ">>> OpenJDK 8 nao disponivel nos repositorios. Tentando alternativa..."

    # Instalar via adicao de repositorio
    if apt-get install -y software-properties-common 2>/dev/null; then
        # Tentar repositorio Adoptium/Temurin
        if wget -q -O /tmp/adoptium-key.asc "https://packages.adoptium.net/artifactory/api/gpg/key/public" 2>/dev/null; then
            gpg --dearmor < /tmp/adoptium-key.asc > /usr/share/keyrings/adoptium-keyring.gpg 2>/dev/null || true
            echo "deb [signed-by=/usr/share/keyrings/adoptium-keyring.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" \
                > /etc/apt/sources.list.d/adoptium.list
            apt-get update
            apt-get install -y temurin-8-jre || {
                echo ">>> AVISO: Falha ao instalar Java 8 via Adoptium."
            }
            rm -f /tmp/adoptium-key.asc
        else
            echo ">>> AVISO: Nao foi possivel obter chave do repositorio Java 8."
        fi
    fi
fi

# Verificar Java 8
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -1)
    echo ">>> Java instalado: $JAVA_VERSION"
else
    echo ">>> AVISO: Java nao instalado."
fi

# ============================================================
# Firefox 52.7 ESR (para applets Java)
# ============================================================
echo ">>> Instalando Firefox 52.7 ESR..."

FF_LEGADO_DIR="/opt/firefox-legado"
FF_LEGADO_TARBALL="/tmp/firefox-52.7-esr.tar.bz2"
FF_LEGADO_URL="${BASE_URL}/downloads/firefox-52.7.3esr.tar.bz2"

# Criar diretorio
mkdir -p /opt

# Tentar baixar do repositorio interno
if wget -q -O "$FF_LEGADO_TARBALL" "$FF_LEGADO_URL" 2>/dev/null; then
    echo ">>> Firefox 52.7 baixado do repositorio interno"
    tar xjf "$FF_LEGADO_TARBALL" -C /opt/
    mv /opt/firefox "$FF_LEGADO_DIR" 2>/dev/null || true
    rm -f "$FF_LEGADO_TARBALL"
else
    echo ">>> AVISO: Nao foi possivel baixar Firefox 52.7 do repositorio interno."
    echo ">>> Tentando download da Mozilla..."

    FF_MOZILLA_URL="https://ftp.mozilla.org/pub/firefox/releases/52.7.3esr/linux-x86_64/en-US/firefox-52.7.3esr.tar.bz2"
    if wget -q -O "$FF_LEGADO_TARBALL" "$FF_MOZILLA_URL" 2>/dev/null; then
        tar xjf "$FF_LEGADO_TARBALL" -C /opt/
        mv /opt/firefox "$FF_LEGADO_DIR" 2>/dev/null || true
        rm -f "$FF_LEGADO_TARBALL"
    else
        echo ">>> AVISO: Nao foi possivel baixar Firefox 52.7."
    fi
fi

# Criar link simbolico
if [ -d "$FF_LEGADO_DIR" ]; then
    ln -sf "${FF_LEGADO_DIR}/firefox" /usr/local/bin/firefox-legado
    echo ">>> Firefox 52.7 ESR instalado em: $FF_LEGADO_DIR"

    # Criar entrada de desktop
    mkdir -p /usr/share/applications
    cat > /usr/share/applications/firefox-legado.desktop <<EOF
[Desktop Entry]
Version=1.0
Name=Firefox 52.7 ESR (Legado)
Comment=Navegador Firefox 52.7 ESR para sistemas legados
Exec=${FF_LEGADO_DIR}/firefox
Icon=${FF_LEGADO_DIR}/browser/icons/mozicon128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF
    echo ">>> Entrada de desktop criada"
else
    echo ">>> AVISO: Firefox 52.7 ESR nao instalado."
fi

# ============================================================
# Configurar plugin Java para Firefox legado
# ============================================================
echo ">>> Configurando plugin Java para Firefox legado..."
if [ -d "$FF_LEGADO_DIR" ] && command -v java &> /dev/null; then
    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    PLUGIN_DIR="${FF_LEGADO_DIR}/browser/plugins"
    mkdir -p "$PLUGIN_DIR"

    # Localizar libnpjp2.so
    find "$JAVA_HOME" -name "libnpjp2.so" -exec ln -sf {} "$PLUGIN_DIR/libnpjp2.so" \; 2>/dev/null || {
        echo ">>> AVISO: Plugin Java (libnpjp2.so) nao encontrado."
    }
    echo ">>> Plugin Java configurado"
fi

echo ">>> [12] Sistemas legados instalados!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    12,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 13 - Identidade Visual (Branding)
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Identidade Visual (Branding)',
    'core_branding.sh',
    'Aplica identidade visual da OM: wallpaper, logo, tema GTK e configuracoes de aparencia por DE.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_branding.sh
# SeederLinux Lite - Wallpaper, logo, tema (varia por DE)
# ============================================================================
# Aplica identidade visual da OM: wallpaper, logo, tema GTK e configuracoes
# de aparencia. Varia conforme o ambiente grafico (DE).
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "13 - Aplicar identidade visual (branding)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
OM_ACRONYM="{{OM_ACRONYM}}"
OM_NAME="{{OM_NAME}}"
DISPLAY_NAME="{{DISPLAY_NAME}}"
WALLPAPER_URL="{{WALLPAPER_URL}}"
WALLPAPER_LOGIN_URL="{{WALLPAPER_LOGIN_URL}}"
LOGO_URL="{{LOGO_URL}}"
GREETER_URL="{{GREETER_URL}}"
THEME="{{THEME}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"

echo ">>> OM: $OM_ACRONYM - $OM_NAME"
echo ">>> Ambiente: $DESKTOP_ENV / $DISPLAY_MANAGER"
echo ">>> Tema: $THEME"

# ============================================================
# Criar diretorios de branding
# ============================================================
mkdir -p /usr/share/seederlinux/branding
mkdir -p /usr/share/backgrounds/seederlinux
mkdir -p /usr/share/pixmaps

# ============================================================
# Baixar e instalar wallpaper
# ============================================================
echo ">>> Baixando wallpaper..."
if [ -n "$WALLPAPER_URL" ] && [ "$WALLPAPER_URL" != "" ]; then
    if wget -q -O /usr/share/backgrounds/seederlinux/wallpaper.jpg "$WALLPAPER_URL"; then
        echo ">>> Wallpaper instalado"
    else
        echo ">>> AVISO: Falha ao baixar wallpaper de: $WALLPAPER_URL"
    fi
else
    echo ">>> WALLPAPER_URL nao definido. Pulando wallpaper."
fi

# ============================================================
# Baixar e instalar wallpaper de login
# ============================================================
echo ">>> Baixando wallpaper de login..."
if [ -n "$WALLPAPER_LOGIN_URL" ] && [ "$WALLPAPER_LOGIN_URL" != "" ]; then
    if wget -q -O /usr/share/backgrounds/seederlinux/wallpaper-login.jpg "$WALLPAPER_LOGIN_URL"; then
        echo ">>> Wallpaper de login instalado"
    else
        echo ">>> AVISO: Falha ao baixar wallpaper de login"
    fi
fi

# ============================================================
# Baixar e instalar logo
# ============================================================
echo ">>> Baixando logo..."
if [ -n "$LOGO_URL" ] && [ "$LOGO_URL" != "" ]; then
    if wget -q -O /usr/share/pixmaps/seederlinux-logo.png "$LOGO_URL"; then
        echo ">>> Logo instalado"
    else
        echo ">>> AVISO: Falha ao baixar logo"
    fi
fi

# ============================================================
# Baixar e instalar greeter personalizado
# ============================================================
echo ">>> Baixando greeter..."
if [ -n "$GREETER_URL" ] && [ "$GREETER_URL" != "" ]; then
    GREETER_TARBALL="/tmp/seederlinux-greeter.tar.gz"
    if wget -q -O "$GREETER_TARBALL" "$GREETER_URL"; then
        mkdir -p /tmp/seederlinux-greeter
        tar xzf "$GREETER_TARBALL" -C /tmp/seederlinux-greeter
        # Copiar para o local apropriado conforme o DM
        case "$DISPLAY_MANAGER" in
            lightdm)
                cp -r /tmp/seederlinux-greeter/* /usr/share/lightdm/ 2>/dev/null || true
                ;;
            gdm3)
                cp -r /tmp/seederlinux-greeter/* /usr/share/gdm/ 2>/dev/null || true
                ;;
            sddm)
                cp -r /tmp/seederlinux-greeter/* /usr/share/sddm/themes/ 2>/dev/null || true
                ;;
        esac
        rm -rf /tmp/seederlinux-greeter "$GREETER_TARBALL"
        echo ">>> Greeter instalado"
    else
        echo ">>> AVISO: Falha ao baixar greeter"
    fi
fi

# ============================================================
# Aplicar tema GTK
# ============================================================
echo ">>> Aplicando tema GTK: $THEME"
if [ -n "$THEME" ] && [ "$THEME" != "" ]; then
    # Configuracao global do tema
    mkdir -p /etc/skel/.config/gtk-3.0
    cat > /etc/skel/.config/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=${THEME}
gtk-icon-theme-name=Adwaita
gtk-font-name=DejaVu Sans 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=16
gtk-toolbar-style=GTK_TOOLBAR_BOTH
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=1
gtk-menu-images=1
gtk-application-prefer-dark-theme=0
EOF
    echo ">>> Tema GTK configurado: $THEME"
fi

# ============================================================
# Aplicar wallpaper e configuracoes conforme o DE
# ============================================================
echo ">>> Aplicando configuracoes para: $DESKTOP_ENV"

case "$DESKTOP_ENV" in
    cinnamon)
        # Cinnamon - via gsettings (schema global)
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/cinnamon-settings.conf <<EOF
[org.cinnamon.desktop.background]
picture-uri=''file:///usr/share/backgrounds/seederlinux/wallpaper.jpg''
picture-options=''zoom''

[org.cinnamon.desktop.interface]
gtk-theme=''${THEME}''
icon-theme=''Adwaita''

[org.cinnamon.theme]
name=''${THEME}''
EOF
        ;;

    mate)
        # MATE - via gsettings
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/mate-background.conf <<EOF
[org.mate.desktop.background]
picture-filename=''/usr/share/backgrounds/seederlinux/wallpaper.jpg''
picture-options=''zoom''

[org.mate.desktop.interface]
gtk-theme=''${THEME}''
icon-theme=''Adwaita''
EOF
        ;;

    gnome)
        # GNOME - via gsettings (dconf)
        mkdir -p /etc/dconf/db/local.d
        cat > /etc/dconf/db/local.d/seederlinux-branding <<EOF
[org/gnome/desktop/background]
picture-uri=''file:///usr/share/backgrounds/seederlinux/wallpaper.jpg''
picture-uri-dark=''file:///usr/share/backgrounds/seederlinux/wallpaper.jpg''
picture-options=''zoom''

[org/gnome/desktop/interface]
gtk-theme=''${THEME}''
icon-theme=''Adwaita''

[org/gnome/login-screen]
logo=''/usr/share/pixmaps/seederlinux-logo.png''
EOF
        dconf update 2>/dev/null || true
        ;;

    xfce)
        # XFCE - via xfconf
        mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml
        cat > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="image-path" type="string" value="/usr/share/backgrounds/seederlinux/wallpaper.jpg"/>
        <property name="image-style" type="int" value="5"/>
      </property>
    </property>
  </property>
</channel>
EOF
        ;;

    kde)
        # KDE Plasma - via kdeglobals
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/kdeglobals <<EOF
[General]
ColorScheme=${THEME}
Name=${THEME}

[KDE]
widgetStyle=${THEME}
EOF
        # Wallpaper via plasma config
        mkdir -p /etc/skel/.config
        cat > /etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc <<EOF
[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///usr/share/backgrounds/seederlinux/wallpaper.jpg
EOF
        ;;

    lxde)
        # LXDE - via pcmanfm
        mkdir -p /etc/skel/.config/pcmanfm/LXDE
        cat > /etc/skel/.config/pcmanfm/LXDE/pcmanfm.conf <<EOF
[desktop]
wallpaper_mode=crop
wallpaper=/usr/share/backgrounds/seederlinux/wallpaper.jpg
EOF
        ;;
esac

# ============================================================
# Configurar wallpaper de login (greeter)
# ============================================================
echo ">>> Configurando wallpaper de login..."
case "$DISPLAY_MANAGER" in
    lightdm)
        mkdir -p /etc/lightdm
        if [ -f /usr/share/backgrounds/seederlinux/wallpaper-login.jpg ]; then
            cat > /etc/lightdm/lightdm-gtk-greeter.conf <<EOF
[greeter]
background=/usr/share/backgrounds/seederlinux/wallpaper-login.jpg
logo=/usr/share/pixmaps/seederlinux-logo.png
theme-name=${THEME}
icon-theme-name=Adwaita
font-name=DejaVu Sans 10
EOF
        fi
        ;;
    gdm3)
        if [ -f /usr/share/backgrounds/seederlinux/wallpaper-login.jpg ]; then
            # GDM3 usa dconf para configuracao
            mkdir -p /etc/dconf/db/gdm.d
            cat > /etc/dconf/db/gdm.d/01-seederlinux-background <<EOF
[org/gnome/desktop/background]
picture-uri=''file:///usr/share/backgrounds/seederlinux/wallpaper-login.jpg''
picture-options=''zoom''
EOF
            dconf update 2>/dev/null || true
        fi
        ;;
    sddm)
        if [ -f /usr/share/backgrounds/seederlinux/wallpaper-login.jpg ]; then
            mkdir -p /etc/sddm.conf.d
            cat > /etc/sddm.conf.d/seederlinux.conf <<EOF
[Theme]
ThemeDir=/usr/share/sddm/themes
Current=seederlinux
Background=/usr/share/backgrounds/seederlinux/wallpaper-login.jpg
EOF
        fi
        ;;
esac

echo ">>> [13] Identidade visual aplicada!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    13,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 14 - LightDM: Logon/Logoff
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'LightDM: Logon/Logoff',
    'core_session_lightdm.sh',
    'Configura o LightDM como display manager e define scripts de logon/logoff para MATE, Cinnamon, XFCE e LXDE.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_session_lightdm.sh
# SeederLinux Lite - LightDM: logon/logoff (MATE, Cinnamon, XFCE, LXDE)
# ============================================================================
# Configura o LightDM como display manager e define os scripts de logon
# e logoff que serao executados nas transicoes de sessao.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "14a - Configurar LightDM (MATE, Cinnamon, XFCE, LXDE)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
BASE_URL="{{BASE_URL}}"
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
GRUPO_ADMIN_AD="{{GRUPO_ADMIN_AD}}"

echo ">>> Display Manager: $DISPLAY_MANAGER"
echo ">>> Ambiente: $DESKTOP_ENV"

# ============================================================
# Verificar se este script deve ser executado
# ============================================================
if [ "$DISPLAY_MANAGER" != "lightdm" ]; then
    echo ">>> Display Manager nao e lightdm. Pulando este script."
    echo ">>> [14a] LightDM nao configurado (DM diferente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Instalar LightDM
# ============================================================
echo ">>> Instalando LightDM..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y lightdm lightdm-gtk-greeter

# Garantir que o LightDM seja o DM padrao
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections 2>/dev/null || true
echo "lightdm lightdm/daemon_name string lightdm" | debconf-set-selections 2>/dev/null || true

# ============================================================
# Configurar LightDM
# ============================================================
echo ">>> Configurando LightDM..."
mkdir -p /etc/lightdm

cat > /etc/lightdm/lightdm.conf <<EOF
# Configuracao LightDM - SeederLinux
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=${DESKTOP_ENV}
allow-guest=false
greeter-hide-users=true
greeter-show-manual-login=true
session-wrapper=/etc/lightdm/Xsession
pam-service=lightdm
pam-autologin-service=lightdm-autologin

# Executar scripts de logon/logoff
session-setup-script=/usr/local/bin/seederlinux-logon
session-cleanup-script=/usr/local/bin/seederlinux-logoff
EOF

echo ">>> LightDM configurado"

# ============================================================
# Configurar greeter do LightDM
# ============================================================
echo ">>> Configurando greeter..."
mkdir -p /etc/lightdm

cat > /etc/lightdm/lightdm-gtk-greeter.conf <<EOF
[greeter]
theme-name = {{THEME}}
icon-theme-name = Adwaita
font-name = DejaVu Sans 10
background = /usr/share/backgrounds/seederlinux/wallpaper-login.jpg
logo = /usr/share/pixmaps/seederlinux-logo.png
show-indicators = ~host;~spacer;~clock;~spacer;~session;~spacer;~power
EOF

echo ">>> Greeter configurado"

# ============================================================
# Configurar Xsession
# ============================================================
echo ">>> Configurando Xsession..."
if [ ! -f /etc/lightdm/Xsession ]; then
    cat > /etc/lightdm/Xsession <<''XSESSION''
#!/bin/bash
# Xsession do SeederLinux para LightDM
exec /etc/X11/Xsession "$@"
XSESSION
    chmod +x /etc/lightdm/Xsession
fi

# ============================================================
# Garantir que os scripts de logon/logoff existam
# ============================================================
echo ">>> Verificando scripts de logon/logoff..."
for SCRIPT in seederlinux-logon seederlinux-logoff; do
    if [ ! -f "/usr/local/bin/${SCRIPT}" ]; then
        echo ">>> AVISO: /usr/local/bin/${SCRIPT} nao encontrado."
        echo ">>> Os scripts core_logon.sh e core_logoff.sh devem ser executados antes."
    fi
done

# ============================================================
# Desabilitar outros display managers
# ============================================================
echo ">>> Desabilitando outros display managers..."
systemctl disable gdm3 2>/dev/null || true
systemctl disable sddm 2>/dev/null || true
systemctl enable lightdm

# ============================================================
# Reiniciar servico
# ============================================================
echo ">>> Reiniciando LightDM..."
systemctl restart lightdm 2>/dev/null || {
    echo ">>> AVISO: LightDM sera iniciado no proximo boot."
}

echo ">>> [14a] LightDM configurado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    14,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 15 - GDM3: Logon/Logoff
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'GDM3: Logon/Logoff',
    'core_session_gdm3.sh',
    'Configura o GDM3 como display manager e define scripts de logon/logoff para GNOME.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_session_gdm3.sh
# SeederLinux Lite - GDM3: logon/logoff (GNOME)
# ============================================================================
# Configura o GDM3 como display manager e define os scripts de logon
# e logoff que serao executados nas transicoes de sessao.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "14b - Configurar GDM3 (GNOME)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
BASE_URL="{{BASE_URL}}"
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
GRUPO_ADMIN_AD="{{GRUPO_ADMIN_AD}}"

echo ">>> Display Manager: $DISPLAY_MANAGER"
echo ">>> Ambiente: $DESKTOP_ENV"

# ============================================================
# Verificar se este script deve ser executado
# ============================================================
if [ "$DISPLAY_MANAGER" != "gdm3" ]; then
    echo ">>> Display Manager nao e gdm3. Pulando este script."
    echo ">>> [14b] GDM3 nao configurado (DM diferente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Instalar GDM3
# ============================================================
echo ">>> Instalando GDM3..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y gdm3

# Garantir que o GDM3 seja o DM padrao
echo "gdm3 shared/default-x-display-manager select gdm3" | debconf-set-selections 2>/dev/null || true
echo "gdm3 gdm3/daemon_name string gdm3" | debconf-set-selections 2>/dev/null || true

# ============================================================
# Configurar GDM3
# ============================================================
echo ">>> Configurando GDM3..."
mkdir -p /etc/gdm3

cat > /etc/gdm3/daemon.conf <<EOF
# Configuracao GDM3 - SeederLinux
[daemon]
WaylandEnable=false
AutomaticLoginEnable=false
TimedLoginEnable=false

[security]
DisallowRoot=true

[greeter]
Session=${DESKTOP_ENV}
EOF

echo ">>> GDM3 configurado"

# ============================================================
# Configurar scripts de logon/logoff via PostSession/PreSession
# ============================================================
echo ">>> Configurando scripts de logon/logoff no GDM3..."

# PreSession - executado antes da sessao do usuario (logon)
PRESESSION_FILE="/etc/gdm3/PreSession/Default"
mkdir -p /etc/gdm3/PreSession

cat > "$PRESESSION_FILE" <<''PRESESSION''
#!/bin/bash
# PreSession do GDM3 - SeederLinux
# Executa o script de logon do SeederLinux
if [ -x /usr/local/bin/seederlinux-logon ]; then
    /usr/local/bin/seederlinux-logon "$@"
fi

exit 0
PRESESSION
chmod +x "$PRESESSION_FILE"

# PostSession - executado apos a sessao do usuario (logoff)
POSTSESSION_FILE="/etc/gdm3/PostSession/Default"
mkdir -p /etc/gdm3/PostSession

cat > "$POSTSESSION_FILE" <<''POSTSESSION''
#!/bin/bash
# PostSession do GDM3 - SeederLinux
# Executa o script de logoff do SeederLinux
if [ -x /usr/local/bin/seederlinux-logoff ]; then
    /usr/local/bin/seederlinux-logoff "$@"
fi

exit 0
POSTSESSION
chmod +x "$POSTSESSION_FILE"

echo ">>> Scripts de logon/logoff configurados no GDM3"

# ============================================================
# Garantir que os scripts de logon/logoff existam
# ============================================================
echo ">>> Verificando scripts de logon/logoff..."
for SCRIPT in seederlinux-logon seederlinux-logoff; do
    if [ ! -f "/usr/local/bin/${SCRIPT}" ]; then
        echo ">>> AVISO: /usr/local/bin/${SCRIPT} nao encontrado."
        echo ">>> Os scripts core_logon.sh e core_logoff.sh devem ser executados antes."
    fi
done

# ============================================================
# Desabilitar outros display managers
# ============================================================
echo ">>> Desabilitando outros display managers..."
systemctl disable lightdm 2>/dev/null || true
systemctl disable sddm 2>/dev/null || true
systemctl enable gdm3

# ============================================================
# Reiniciar servico
# ============================================================
echo ">>> Reiniciando GDM3..."
systemctl restart gdm3 2>/dev/null || {
    echo ">>> AVISO: GDM3 sera iniciado no proximo boot."
}

echo ">>> [14b] GDM3 configurado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    15,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 16 - SDDM: Logon/Logoff
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'SDDM: Logon/Logoff',
    'core_session_sddm.sh',
    'Configura o SDDM como display manager e define scripts de logon/logoff para KDE.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_session_sddm.sh
# SeederLinux Lite - SDDM: logon/logoff (KDE)
# ============================================================================
# Configura o SDDM como display manager e define os scripts de logon
# e logoff que serao executados nas transicoes de sessao.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "14c - Configurar SDDM (KDE)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
BASE_URL="{{BASE_URL}}"
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
GRUPO_ADMIN_AD="{{GRUPO_ADMIN_AD}}"

echo ">>> Display Manager: $DISPLAY_MANAGER"
echo ">>> Ambiente: $DESKTOP_ENV"

# ============================================================
# Verificar se este script deve ser executado
# ============================================================
if [ "$DISPLAY_MANAGER" != "sddm" ]; then
    echo ">>> Display Manager nao e sddm. Pulando este script."
    echo ">>> [14c] SDDM nao configurado (DM diferente)."
    echo "============================================================"
    exit 0
fi

# ============================================================
# Instalar SDDM
# ============================================================
echo ">>> Instalando SDDM..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y sddm sddm-theme-breeze

# Garantir que o SDDM seja o DM padrao
echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections 2>/dev/null || true
echo "sddm sddm/daemon_name string sddm" | debconf-set-selections 2>/dev/null || true

# ============================================================
# Configurar SDDM
# ============================================================
echo ">>> Configurando SDDM..."
mkdir -p /etc/sddm.conf.d

cat > /etc/sddm.conf.d/seederlinux.conf <<EOF
# Configuracao SDDM - SeederLinux
[Theme]
Current=breeze
ThemeDir=/usr/share/sddm/themes

[Users]
MaximumUid=60000
MinimumUid=1000

[Autologin]
User=
Session=
EOF

echo ">>> SDDM configurado"

# ============================================================
# Configurar scripts de logon/logoff via Xsession
# ============================================================
echo ">>> Configurando scripts de logon/logoff no SDDM..."

# SDDM executa /etc/X11/Xsession que por sua vez pode chamar scripts.
# Para integrar logon/logoff, usamos o Xsetup e Xstop do SDDM.

# Xsetup - executado antes da sessao (logon)
XSETUP_FILE="/usr/share/sddm/scripts/Xsetup"
mkdir -p /usr/share/sddm/scripts

cat > "$XSETUP_FILE" <<''XSETUP''
#!/bin/bash
# Xsetup do SDDM - SeederLinux
# Executa o script de logon do SeederLinux
if [ -x /usr/local/bin/seederlinux-logon ]; then
    /usr/local/bin/seederlinux-logon "$@"
fi

exit 0
XSETUP
chmod +x "$XSETUP_FILE"

# Xstop - executado apos a sessao (logoff)
XSTOP_FILE="/usr/share/sddm/scripts/Xstop"

cat > "$XSTOP_FILE" <<''XSTOP''
#!/bin/bash
# Xstop do SDDM - SeederLinux
# Executa o script de logoff do SeederLinux
if [ -x /usr/local/bin/seederlinux-logoff ]; then
    /usr/local/bin/seederlinux-logoff "$@"
fi

exit 0
XSTOP
chmod +x "$XSTOP_FILE"

echo ">>> Scripts de logon/logoff configurados no SDDM"

# ============================================================
# Garantir que os scripts de logon/logoff existam
# ============================================================
echo ">>> Verificando scripts de logon/logoff..."
for SCRIPT in seederlinux-logon seederlinux-logoff; do
    if [ ! -f "/usr/local/bin/${SCRIPT}" ]; then
        echo ">>> AVISO: /usr/local/bin/${SCRIPT} nao encontrado."
        echo ">>> Os scripts core_logon.sh e core_logoff.sh devem ser executados antes."
    fi
done

# ============================================================
# Desabilitar outros display managers
# ============================================================
echo ">>> Desabilitando outros display managers..."
systemctl disable lightdm 2>/dev/null || true
systemctl disable gdm3 2>/dev/null || true
systemctl enable sddm

# ============================================================
# Reiniciar servico
# ============================================================
echo ">>> Reiniciando SDDM..."
systemctl restart sddm 2>/dev/null || {
    echo ">>> AVISO: SDDM sera iniciado no proximo boot."
}

echo ">>> [14c] SDDM configurado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    16,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 17 - Logon do Usuario (kixtart_v2)
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Logon do Usuario (kixtart_v2)',
    'core_logon.sh',
    'Script executado no login do usuario: mapeamento de compartilhamentos, atalhos e personalizacoes.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_logon.sh
# SeederLinux Lite - kixtart_v2.sh (executado no login do usuario)
# ============================================================================
# Script executado no momento do login do usuario. Realiza ajustes de
# ambiente, mapeamento de compartilhamentos de rede, configuracao de
# atalhos e personalizacoes por usuario.
# Origem: kixtart_v2.sh do projeto SoftwareLivre.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "15 - Logon do usuario (kixtart_v2)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
SERVIDOR_ARQUIVOS="{{SERVIDOR_ARQUIVOS}}"
COMPARTILHAMENTOS="{{COMPARTILHAMENTOS}}"
MOUNT_BASE="{{MOUNT_BASE}}"
HOMEPAGE="{{HOMEPAGE}}"
OM_ACRONYM="{{OM_ACRONYM}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
DEFAULT_PRINTER="{{DEFAULT_PRINTER}}"

# Obter usuario logado
USERNAME="${USER:-$(whoami)}"
USER_HOME="${HOME:-/home/$USERNAME}"

echo ">>> Usuario: $USERNAME"
echo ">>> Home: $USER_HOME"

# ============================================================
# Criar diretorios base do usuario
# ============================================================
echo ">>> Criando diretorios do usuario..."
mkdir -p "$USER_HOME/Desktop"
mkdir -p "$USER_HOME/Downloads"
mkdir -p "$USER_HOME/Documents"
mkdir -p "$USER_HOME/.config"
mkdir -p "$USER_HOME/.local/share/applications"

# ============================================================
# Mapear compartilhamentos de rede
# ============================================================
echo ">>> Mapeando compartilhamentos de rede..."

if [ -n "$SERVIDOR_ARQUIVOS" ] && [ "$SERVIDOR_ARQUIVOS" != "" ]; then
    # Criar diretorio base de montagem
    MOUNT_DIR="${MOUNT_BASE:-/mnt}"
    mkdir -p "$MOUNT_DIR"

    if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
        for SHARE in $COMPARTILHAMENTOS; do
            SHARE_MOUNT="${MOUNT_DIR}/${SHARE}"
            mkdir -p "$SHARE_MOUNT"

            # Montar compartilhamento CIFS
            mountpoint -q "$SHARE_MOUNT" 2>/dev/null || {
                mount -t cifs "//${SERVIDOR_ARQUIVOS}/${SHARE}" "$SHARE_MOUNT" \
                    -o "username=${USERNAME},domain=${DOMINIO_NETBIOS},uid=$(id -u),gid=$(id -g),iocharset=utf8,vers=3.0" 2>/dev/null || {
                    echo ">>> AVISO: Falha ao montar //${SERVIDOR_ARQUIVOS}/${SHARE}"
                }
            }
            echo ">>> Compartilhamento montado: ${SHARE} em ${SHARE_MOUNT}"

            # Criar atalho no desktop
            cat > "$USER_HOME/Desktop/${SHARE}.desktop" <<EOF
[Desktop Entry]
Type=Link
Name=${SHARE}
URL=file://${SHARE_MOUNT}
Icon=folder
EOF
            chmod +x "$USER_HOME/Desktop/${SHARE}.desktop" 2>/dev/null || true
        done
    else
        echo ">>> Nenhum compartilhamento listado."
    fi
else
    echo ">>> SERVIDOR_ARQUIVOS nao definido. Pulando mapeamento."
fi

# ============================================================
# Configurar impressora padrao
# ============================================================
echo ">>> Configurando impressora padrao..."
if [ -n "$DEFAULT_PRINTER" ] && [ "$DEFAULT_PRINTER" != "" ]; then
    lpoptions -d "$DEFAULT_PRINTER" 2>/dev/null || {
        echo ">>> AVISO: Falha ao definir impressora padrao: $DEFAULT_PRINTER"
    }
    echo ">>> Impressora padrao: $DEFAULT_PRINTER"
fi

# ============================================================
# Criar atalhos no desktop
# ============================================================
echo ">>> Criando atalhos no desktop..."

# Atalho para o portal/homepage
if [ -n "$HOMEPAGE" ] && [ "$HOMEPAGE" != "" ]; then
    cat > "$USER_HOME/Desktop/Portal-${OM_ACRONYM}.desktop" <<EOF
[Desktop Entry]
Type=Link
Name=Portal ${OM_ACRONYM}
URL=${HOMEPAGE}
Icon=firefox-esr
EOF
    chmod +x "$USER_HOME/Desktop/Portal-${OM_ACRONYM}.desktop" 2>/dev/null || true
    echo ">>> Atalho do portal criado"
fi

# ============================================================
# Aplicar configuracoes de ambiente por DE
# ============================================================
echo ">>> Aplicando configuracoes de ambiente: $DESKTOP_ENV"

case "$DESKTOP_ENV" in
    cinnamon|mate)
        # Garantir que o Conky inicie
        if [ -x /usr/local/bin/seederlinux-conky ]; then
            /usr/local/bin/seederlinux-conky &
        fi
        ;;
    gnome)
        # GNOME: desativar animacoes para desempenho
        gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
        ;;
    xfce)
        # XFCE: garantir painel padrao
        ;;
    kde)
        # KDE: configurar atalhos
        ;;
    lxde)
        # LXDE: garantir configuracao do pcmanfm
        ;;
esac

# ============================================================
# Corrigir permissoes do home
# ============================================================
echo ">>> Corrigindo permissoes do home..."
chown -R "$USERNAME:$(id -gn)" "$USER_HOME" 2>/dev/null || true

# ============================================================
# Mensagem de boas-vindas
# ============================================================
echo ">>> Bem-vindo ao ${OM_ACRONYM}!"
echo ">>> Logon do usuario concluido."

echo ">>> [15] Logon concluido!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    17,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

-- 18 - Logoff do Usuario (kixtop_v2)
INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Logoff do Usuario (kixtop_v2)',
    'core_logoff.sh',
    'Script executado no logoff: limpeza de temporarios, desmontagem de compartilhamentos e remocao de atalhos.',
    '#!/bin/bash
# ============================================================================
# Core Script: core_logoff.sh
# SeederLinux Lite - kixtop_v2.sh (executado no logoff do usuario)
# ============================================================================
# Script executado no momento do logoff do usuario. Realiza limpeza de
# arquivos temporarios, desmontagem de compartilhamentos e remocao de
# atalhos temporarios.
# Origem: kixtop_v2.sh do projeto SoftwareLivre.
# Os placeholders {{VARIAVEL}} são substituídos automaticamente
# pelo sistema na geração do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "16 - Logoff do usuario (kixtop_v2)"
echo "============================================================"

# ============================================================
# Variáveis
# ============================================================
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
SERVIDOR_ARQUIVOS="{{SERVIDOR_ARQUIVOS}}"
COMPARTILHAMENTOS="{{COMPARTILHAMENTOS}}"
MOUNT_BASE="{{MOUNT_BASE}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"

# Obter usuario logado
USERNAME="${USER:-$(whoami)}"
USER_HOME="${HOME:-/home/$USERNAME}"

echo ">>> Usuario: $USERNAME"
echo ">>> Home: $USER_HOME"

# ============================================================
# Desmontar compartilhamentos de rede
# ============================================================
echo ">>> Desmontando compartilhamentos de rede..."

if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
    MOUNT_DIR="${MOUNT_BASE:-/mnt}"

    for SHARE in $COMPARTILHAMENTOS; do
        SHARE_MOUNT="${MOUNT_DIR}/${SHARE}"
        if mountpoint -q "$SHARE_MOUNT" 2>/dev/null; then
            umount "$SHARE_MOUNT" 2>/dev/null || {
                echo ">>> AVISO: Falha ao desmontar ${SHARE_MOUNT}"
                # Forcar lazy unmount se necessario
                umount -l "$SHARE_MOUNT" 2>/dev/null || true
            }
            echo ">>> Compartilhamento desmontado: ${SHARE}"
        fi
    done
else
    echo ">>> Nenhum compartilhamento para desmontar."
fi

# ============================================================
# Limpar arquivos temporarios do usuario
# ============================================================
echo ">>> Limpando arquivos temporarios..."

# Cache do navegador
rm -rf "$USER_HOME/.cache/mozilla" 2>/dev/null || true
rm -rf "$USER_HOME/.cache/google-chrome" 2>/dev/null || true
rm -rf "$USER_HOME/.cache/chromium" 2>/dev/null || true

# Arquivos temporarios
rm -rf "$USER_HOME/.local/share/Trash"/* 2>/dev/null || true
find /tmp -user "$USERNAME" -type f -mmin +60 -delete 2>/dev/null || true

# Thumbnails
rm -rf "$USER_HOME/.cache/thumbnails" 2>/dev/null || true

echo ">>> Limpeza concluida"

# ============================================================
# Remover atalhos temporarios do desktop
# ============================================================
echo ">>> Removendo atalhos temporarios..."

# Remover atalhos de compartilhamentos
if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
    for SHARE in $COMPARTILHAMENTOS; do
        rm -f "$USER_HOME/Desktop/${SHARE}.desktop" 2>/dev/null || true
    done
fi

echo ">>> Atalhos temporarios removidos"

# ============================================================
# Salvar estado da sessao (logs)
# ============================================================
echo ">>> Salvando estado da sessao..."

LOG_DIR="/var/log/seederlinux"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/session-${USERNAME}-$(date +%Y%m%d).log"
echo "[$(date ''+%Y-%m-%d %H:%M:%S'')] Logoff do usuario $USERNAME" >> "$LOG_FILE"

# Rotacionar logs antigos (manter 7 dias)
find "$LOG_DIR" -name "session-*.log" -mtime +7 -delete 2>/dev/null || true

echo ">>> Estado da sessao salvo"

# ============================================================
# Encerrar processos do usuario
# ============================================================
echo ">>> Encerrando processos do usuario..."

# Matar processos Conky
killall -u "$USERNAME" conky 2>/dev/null || true

# Matar processos x11vnc
killall -u "$USERNAME" x11vnc 2>/dev/null || true

echo ">>> Processos encerrados"

echo ">>> [16] Logoff concluido!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    18,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

INSERT INTO scripts (name, filename, description, content, is_core, is_active, execution_order, version, organization_id)
VALUES (
    'Configuracao Persistente',
    'core_config.sh',
    'Cria /etc/seederlinux/config.env com variaveis nao-sensiveis para uso apos reboot',
    '#!/bin/bash
# ============================================================================
# Core Script: core_config.sh
# SeederLinux Lite - Arquivo de Configuracao Persistente
# ============================================================================
# Cria /etc/seederlinux/config.env com todas as variaveis nao-sensiveis
# da OM. Este arquivo e lido pelos scripts permanentes (seederlinux-logon,
# seederlinux-logoff) apos reboot, quando as variaveis exportadas no bundle
# ja nao existem mais na memoria.
#
# Variaveis sensiveis (senha VNC, usuario admin do AD) NAO sao escritas
# neste arquivo. Elas sao gravadas em /etc/seederlinux/secrets.env (perm 600)
# apenas pelo core_vnc.sh e core_domain.sh respectivamente.
#
# Os placeholders {{VARIAVEL}} sao substituidos automaticamente
# pelo sistema na geracao do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "13.5 - Criar arquivo de configuracao persistente"
echo "============================================================"

# ============================================================
# Diretorio base
# ============================================================
mkdir -p /etc/seederlinux

CONFIG_FILE="/etc/seederlinux/config.env"

# ============================================================
# Escrever variaveis nao-sensiveis no config.env
# Variaveis sensiveis (VNC_PASSWORD, ADMIN_USERNAME) ficam em
# /etc/seederlinux/secrets.env, gravadas por seus respectivos scripts.
# ============================================================
cat > "$CONFIG_FILE" <<EOF
# SeederLinux Lite - Configuracao Persistente
# NAO EDITAR MANUALMENTE - gerado pelo core_config.sh
# Gerado em: $(date ''+%Y-%m-%d %H:%M:%S'')

# Dominio e Autenticacao
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
DC_IP="{{DC_IP}}"
DC_IP_LIST="{{DC_IP_LIST}}"
DC_SECUNDARIO_IP="{{DC_SECUNDARIO_IP}}"
DNS_PRIMARIO="{{DNS_PRIMARIO}}"
DNS_SECUNDARIO="{{DNS_SECUNDARIO}}"
DNS_INTERNET="{{DNS_INTERNET}}"
NTP_SERVER="{{NTP_SERVER}}"
OU_PADRAO="{{OU_PADRAO}}"
GRUPO_ADMIN="{{GRUPO_ADMIN}}"
GRUPO_ADMIN_AD="{{GRUPO_ADMIN_AD}}"
GRUPO_ADMIN_LINUX="{{GRUPO_ADMIN_LINUX}}"
GRUPO_DASTI="{{GRUPO_DASTI}}"
AUTH_METHOD="{{AUTH_METHOD}}"
OFFLINE_AUTH_ENABLED="{{OFFLINE_AUTH_ENABLED}}"
OFFLINE_AUTH_DAYS="{{OFFLINE_AUTH_DAYS}}"

# Rede e Proxy
PROXY_HTTP="{{PROXY_HTTP}}"
PROXY_PORTA="{{PROXY_PORTA}}"
PROXY_URL="{{PROXY_URL}}"
PROXY_MODE="{{PROXY_MODE}}"
PAC_URL="{{PAC_URL}}"
NO_PROXY="{{NO_PROXY}}"

# URLs e Servidores
BASE_URL="{{BASE_URL}}"
HOMEPAGE="{{HOMEPAGE}}"
OCS_SERVER="{{OCS_SERVER}}"
OCS_TAG="{{OCS_TAG}}"
GLPI_SERVER="{{GLPI_SERVER}}"
PRINT_SERVER="{{PRINT_SERVER}}"
SERVIDOR_ARQUIVOS="{{SERVIDOR_ARQUIVOS}}"

# Identidade Visual
OM_ACRONYM="{{OM_ACRONYM}}"
OM_NAME="{{OM_NAME}}"
DISPLAY_NAME="{{DISPLAY_NAME}}"
WALLPAPER_URL="{{WALLPAPER_URL}}"
WALLPAPER_LOGIN_URL="{{WALLPAPER_LOGIN_URL}}"
LOGO_URL="{{LOGO_URL}}"
GREETER_URL="{{GREETER_URL}}"
THEME="{{THEME}}"

# Ambiente Grafico
DESKTOP_ENV="{{DESKTOP_ENV}}"
DISPLAY_MANAGER="{{DISPLAY_MANAGER}}"

# Aplicacoes e Funcionalidades
INSTALL_APPS="{{INSTALL_APPS}}"
INSTALL_LEGADOS="{{INSTALL_LEGADOS}}"
VNC_ENABLED="{{VNC_ENABLED}}"
INVENTORY_ENABLED="{{INVENTORY_ENABLED}}"

# Repositorios
REPOSITORY_MODE="{{REPOSITORY_MODE}}"
REPOSITORY_URL="{{REPOSITORY_URL}}"
REPOSITORY_FALLBACK="{{REPOSITORY_FALLBACK}}"

# Compartilhamentos e Impressoras
COMPARTILHAMENTOS="{{COMPARTILHAMENTOS}}"
MOUNT_BASE="{{MOUNT_BASE}}"
DEFAULT_PRINTER="{{DEFAULT_PRINTER}}"
PRINTERS="{{PRINTERS}}"

# Acesso Remoto
REMOTE_METHOD="{{REMOTE_METHOD}}"
REMOTE_SERVER="{{REMOTE_SERVER}}"

# Certificados
CERTIFICATE_BUNDLE="{{CERTIFICATE_BUNDLE}}"
CERTIFICATE_AUTO_INSTALL="{{CERTIFICATE_AUTO_INSTALL}}"

# Conky
CONKY_PROFILE="{{CONKY_PROFILE}}"
CONKY_CONFIG=''{{CONKY_CONFIG}}''

# Servidor SeederLinux (para o agente Python)
SEEDER_SERVER="{{SEEDER_SERVER}}"
EOF

chmod 644 "$CONFIG_FILE"

echo ">>> Configuracao persistente gravada em $CONFIG_FILE"
echo ">>> [13.5] Arquivo de configuracao criado!"
echo "============================================================"
',
    true,  -- is_core
    true,  -- is_active
    13.5,  -- execution_order
    1,     -- version
    NULL   -- organization_id (disponivel para todas as OMs)
);

COMMIT;

-- ============================================================================
-- Total de scripts Core inseridos: 19
-- Ordem de execucao no bundle:
--   01-13: Scripts sequenciais (repositorios -> branding)
--   13.5: Configuracao persistente (core_config.sh)
--   14-16: Scripts de sessao (apenas UM conforme DISPLAY_MANAGER)
--   17-18: Logon e Logoff
-- ============================================================================
