#!/bin/bash
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
