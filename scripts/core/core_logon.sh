#!/bin/bash
# ============================================================================
# Core Script: core_logon.sh
# SeederLinux Lite - kixtart_v2.sh (executado no login do usuario)
# ============================================================================
# Script executado no momento do login do usuario. Realiza ajustes de
# ambiente, mapeamento de compartilhementos de rede, configuracao de
# atalhos e personalizacoes por usuario.
# Origem: kixtart_v2.sh do projeto SoftwareLivre.
# Os placeholders {{VARIAVEL}} sao substituidos automaticamente
# pelo sistema na geracao do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "15 - Logon do usuario (kixtart_v2)"
echo "============================================================"

# ============================================================
# Variaveis (substituidas no bundle)
# ============================================================
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
SERVIDOR_ARQUIVOS="{{SERVIDOR_ARQUIVOS}}"
COMPARTILHAMENTOS="{{COMPARTILHAMENTOS}}"
MOUNT_BASE="{{MOUNT_BASE}}"
HOMEPAGE="{{HOMEPAGE}}"
OM_ACROONM="{{OM_ACRONYM}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"
DEFAULT_PRINTER="{{DEFAULT_PRINTER}}"

# ============================================================
# Detectar ambiente grafico se nao definido
# ============================================================
if [ -z "$DESKTOP_ENV" ] || [ "$DESKTOP_ENV" = "" ]; then
    if command -v cinnamon-session &>/dev/null; then DESKTOP_ENV="cinnamon"
    elif command -v mate-session &>/dev/null; then DESKTOP_ENV="mate"
    elif command -v gnome-session &>/dev/null; then DESKTOP_ENV="gnome"
    elif command -v startxfce4 &>/dev/null; then DESKTOP_ENV="xfce"
    elif command -v startplasma-x11 &>/dev/null; then DESKTOP_ENV="kde"
    elif command -v startlxde &>/dev/null; then DESKTOP_ENV="lxde"
    else DESKTOP_ENV="unknown"
    fi
    echo ">>> DE detectado automaticamente: $DESKTOP_ENV"
fi

# ============================================================
# FUNCAO: logica de logon executada tanto no bundle quanto
#         no script permanente em /usr/local/bin/seederlinux-logon
# ============================================================
seederlinux_logon() {
    local DOMINIO="$1"
    local DOMINIO_NETBIOS="$2"
    local SERVIDOR_ARQUIVOS="$3"
    local COMPARTILHAMENTOS="$4"
    local MOUNT_BASE="$5"
    local HOMEPAGE="$6"
    local OM_ACRONYM="$7"
    local DESKTOP_ENV="$8"
    local DEFAULT_PRINTER="$9"

    # Obter usuario logado
    local USERNAME="${USER:-$(whoami)}"
    local USER_HOME="${HOME:-/home/$USERNAME}"

    echo ">>> [logon] Usuario: $USERNAME"
    echo ">>> [logon] Home: $USER_HOME"

    # Criar diretorios base do usuario
    mkdir -p "$USER_HOME/Desktop"
    mkdir -p "$USER_HOME/Downloads"
    mkdir -p "$USER_HOME/Documents"
    mkdir -p "$USER_HOME/.config"
    mkdir -p "$USER_HOME/.local/share/applications"

    # Mapear compartilhamentos de rede
    echo ">>> [logon] Mapeando compartilhamentos de rede..."
    if [ -n "$SERVIDOR_ARQUIVOS" ] && [ "$SERVIDOR_ARQUIVOS" != "" ]; then
        local MOUNT_DIR="${MOUNT_BASE:-/mnt}"
        mkdir -p "$MOUNT_DIR"

        if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
            for SHARE in $COMPARTILHAMENTOS; do
                local SHARE_MOUNT="${MOUNT_DIR}/${SHARE}"
                mkdir -p "$SHARE_MOUNT"

                mountpoint -q "$SHARE_MOUNT" 2>/dev/null || {
                    mount -t cifs "//${SERVIDOR_ARQUIVOS}/${SHARE}" "$SHARE_MOUNT" \
                        -o "username=${USERNAME},domain=${DOMINIO_NETBIOS},uid=$(id -u),gid=$(id -g),iocharset=utf8,vers=3.0" 2>/dev/null || {
                        echo ">>> [logon] AVISO: Falha ao montar //${SERVIDOR_ARQUIVOS}/${SHARE}"
                    }
                }
                echo ">>> [logon] Compartilhamento montado: ${SHARE} em ${SHARE_MOUNT}"

                cat > "$USER_HOME/Desktop/${SHARE}.desktop" <<DESKTOP
[Desktop Entry]
Type=Link
Name=${SHARE}
URL=file://${SHARE_MOUNT}
Icon=folder
DESKTOP
                chmod +x "$USER_HOME/Desktop/${SHARE}.desktop" 2>/dev/null || true
            done
        else
            echo ">>> [logon] Nenhum compartilhamento listado."
        fi
    else
        echo ">>> [logon] SERVIDOR_ARQUIVOS nao definido. Pulando mapeamento."
    fi

    # Configurar impressora padrao
    if [ -n "$DEFAULT_PRINTER" ] && [ "$DEFAULT_PRINTER" != "" ]; then
        lpoptions -d "$DEFAULT_PRINTER" 2>/dev/null || {
            echo ">>> [logon] AVISO: Falha ao definir impressora padrao: $DEFAULT_PRINTER"
        }
        echo ">>> [logon] Impressora padrao: $DEFAULT_PRINTER"
    fi

    # Criar atalho do portal no desktop
    if [ -n "$HOMEPAGE" ] && [ "$HOMEPAGE" != "" ]; then
        cat > "$USER_HOME/Desktop/Portal-${OM_ACRONYM}.desktop" <<DESKTOP
[Desktop Entry]
Type=Link
Name=Portal ${OM_ACRONYM}
URL=${HOMEPAGE}
Icon=firefox-esr
DESKTOP
        chmod +x "$USER_HOME/Desktop/Portal-${OM_ACRONYM}.desktop" 2>/dev/null || true
        echo ">>> [logon] Atalho do portal criado"
    fi

    # Aplicar configuracoes de ambiente por DE
    case "$DESKTOP_ENV" in
        cinnamon|mate)
            if [ -x /usr/local/bin/seederlinux-conky ]; then
                /usr/local/bin/seederlinux-conky &
            fi
            ;;
        gnome)
            gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
            ;;
    esac

    # Corrigir permissoes do home
    chown -R "$USERNAME:$(id -gn)" "$USER_HOME" 2>/dev/null || true

    echo ">>> [logon] Bem-vindo ao ${OM_ACRONYM}!"
}

# ============================================================
# 1. Criar o script PERMANENTE em /usr/local/bin/seederlinux-logon
#    Este script sera chamado pelo LightDM/GDM3/SDDM a cada login
#    e le as variaveis de /etc/seederlinux/config.env
# ============================================================
echo ">>> Criando script permanente: /usr/local/bin/seederlinux-logon"

cat > /usr/local/bin/seederlinux-logon <<'PERMSCRIPT'
#!/bin/bash
# seederlinux-logon - Script permanente de logon do SeederLinux
# Executado pelo display manager (LightDM/GDM3/SDDM) a cada login.
# Le as variaveis de /etc/seederlinux/config.env (persistente).

CONFIG_FILE="/etc/seederlinux/config.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo ">>> [logon] AVISO: $CONFIG_FILE nao encontrado. Logon sem configuracao."
    exit 0
fi

# Obter usuario logado
USERNAME="${USER:-$(whoami)}"
USER_HOME="${HOME:-/home/$USERNAME}"

echo ">>> [logon] Usuario: $USERNAME"

# Criar diretorios base do usuario
mkdir -p "$USER_HOME/Desktop" "$USER_HOME/Downloads" "$USER_HOME/Documents"
mkdir -p "$USER_HOME/.config" "$USER_HOME/.local/share/applications"

# Mapear compartilhamentos de rede
if [ -n "$SERVIDOR_ARQUIVOS" ] && [ "$SERVIDOR_ARQUIVOS" != "" ]; then
    MOUNT_DIR="${MOUNT_BASE:-/mnt}"
    mkdir -p "$MOUNT_DIR"

    if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
        for SHARE in $COMPARTILHAMENTOS; do
            SHARE_MOUNT="${MOUNT_DIR}/${SHARE}"
            mkdir -p "$SHARE_MOUNT"

            mountpoint -q "$SHARE_MOUNT" 2>/dev/null || {
                mount -t cifs "//${SERVIDOR_ARQUIVOS}/${SHARE}" "$SHARE_MOUNT" \
                    -o "username=${USERNAME},domain=${DOMINIO_NETBIOS},uid=$(id -u),gid=$(id -g),iocharset=utf8,vers=3.0" 2>/dev/null || {
                    echo ">>> [logon] AVISO: Falha ao montar //${SERVIDOR_ARQUIVOS}/${SHARE}"
                }
            }
            echo ">>> [logon] Compartilhamento montado: ${SHARE}"

            cat > "$USER_HOME/Desktop/${SHARE}.desktop" <<EOF
[Desktop Entry]
Type=Link
Name=${SHARE}
URL=file://${SHARE_MOUNT}
Icon=folder
EOF
            chmod +x "$USER_HOME/Desktop/${SHARE}.desktop" 2>/dev/null || true
        done
    fi
fi

# Configurar impressora padrao
if [ -n "$DEFAULT_PRINTER" ] && [ "$DEFAULT_PRINTER" != "" ]; then
    lpoptions -d "$DEFAULT_PRINTER" 2>/dev/null || true
fi

# Criar atalho do portal
if [ -n "$HOMEPAGE" ] && [ "$HOMEPAGE" != "" ]; then
    cat > "$USER_HOME/Desktop/Portal-${OM_ACRONYM}.desktop" <<EOF
[Desktop Entry]
Type=Link
Name=Portal ${OM_ACRONYM}
URL=${HOMEPAGE}
Icon=firefox-ess
EOF
    chmod +x "$USER_HOME/Desktop/Portal-${OM_ACRONYM}.desktop" 2>/dev/null || true
fi

# Iniciar Conky se disponivel
if [ -x /usr/local/bin/seederlinux-conky ]; then
    /usr/local/bin/seederlinux-conky &
fi

# Corrigir permissoes do home
chown -R "$USERNAME:$(id -gn)" "$USER_HOME" 2>/dev/null || true

echo ">>> [logon] Logon concluido para ${OM_ACRONYM}"
exit 0
PERMSCRIPT

chmod 755 /usr/local/bin/seederlinux-logon
echo ">>> Script permanente criado: /usr/local/bin/seederlinux-logon"

# ============================================================
# 2. Executar a logica de logon AGORA (durante o bundle)
# ============================================================
echo ">>> Executando logica de logon (bundle)..."
seederlinux_logon \
    "$DOMINIO" "$DOMINIO_NETBIOS" "$SERVIDOR_ARQUIVOS" \
    "$COMPARTILHAMENTOS" "$MOUNT_BASE" "$HOMEPAGE" \
    "$OM_ACRONYM" "$DESKTOP_ENV" "$DEFAULT_PRINTER"

echo ">>> [15] Logon concluido!"
echo "============================================================"
