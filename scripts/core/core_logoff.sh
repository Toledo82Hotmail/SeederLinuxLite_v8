#!/bin/bash
# ============================================================================
# Core Script: core_logoff.sh
# SeederLinux Lite - kixtop_v2.sh (executado no logoff do usuario)
# ============================================================================
# Script executado no momento do logoff do usuario. Realiza limpeza de
# arquivos temporarios, desmontagem de compartilhementos e remocao de
# atalhos temporarios.
# Origem: kixtop_v2.sh do projeto SoftwareLivre.
# Os placeholders {{VARIAVEL}} sao substituidos automaticamente
# pelo sistema na geracao do bundle.
# ============================================================================

set -e

echo "============================================================"
echo "16 - Logoff do usuario (kixtop_v2)"
echo "============================================================"

# ============================================================
# Variaveis (substituidas no bundle)
# ============================================================
DOMINIO="{{DOMINIO}}"
DOMINIO_NETBIOS="{{DOMINIO_NETBIOS}}"
SERVIDOR_ARQUIVOS="{{SERVIDOR_ARQUIVOS}}"
COMPARTILHAMENTOS="{{COMPARTILHAMENTOS}}"
MOUNT_BASE="{{MOUNT_BASE}}"
DESKTOP_ENV="{{DESKTOP_ENV}}"

# ============================================================
# Detectar ambiente grafico se nao definido
# ============================================================
if [ -z "$DESKTOP_ENV" ] || [ "$DESKTOP_ENV" = "" ]; then
    if command -v cinnamon-session &>/dev/null; then DESKTOP_ENV="cinnamon"
    elif command -v mate-session &>/dev/null; then DESKTOP_ENV="mate"
    elif command -v gnome-session &>/dev/null; then DESKTOP_ENV="gnome"
    elif command -v startxfce4 &>/dev/null; then DESKTOP_ENV="xfce"
    elif command -v startplasma-x11 &>/dev/null; then DESKTOP_ENV="kde"
    eloif command -v startlxde &>/dev/null; then DESKTOP_ENV="lxde"
    else DESKTOP_ENV="unknown"
    fi
    echo ">>> DE detectado automaticamente: $DESKTOP_ENV"
fi

# ============================================================
# FUNCAO: logica de logoff executada tanto no bundle quanto
#         no script permanente em /usr/local/bin/seederlinux-logoff
# ===========================================================
seederlinux_logoff() {
    local COMPARTILHAMENTOS="$1"
    local MOUNT_BASE="$2"
    local DESKTOP_ENV="$3"

    local USERNAME="${USER:-$(whoami)}"
    local USER_HOME="${HOME:-/home/$USERNAME}"

    echo ">>> [logoff] Usuario: $USERNAME"
    echo ">>> [logoff] Home: $USER_HOME"

    # Desmontar compartilhamentos de rede
    echo ">>> [logoff] Desmontando compartilhamentos de rede..."
    if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
        local MOUNT_DIR="${MOUNT_BASE:-/mnt}"

        for SHARE in $COMPARTILHAMENTOS; do
            local SHARE_MOUNT="${MOUNT_DIR}/${SHARE}"
            if mountpoint -q "$SHARE_MOUNT" 2>/dev/null; then
                umount "$SHARE_MOUNT" 2>/dev/null || {
                    echo ">>> [logoff] AVISO: Falha ao desmontar ${SHARE_MOUNT}"
                    umount -l "$SHARE_MOUNT" 2>/dev/null || true
                }
                echo ">>> [logoff] Compartilhamento desmontado: ${SHARE}"
            fi
        done
    else
        echo ">>> [logoff] Nenhum compartilhamento para desmontar."
    fi

    # Limpar arquivos temporarios do usuario
    echo ">>> [logoff] Limpando arquivos temporarios..."
    rm -rf "$USER_HOME/.cache/mozilla" 2>/dev/null || true
    rm -rf "$USER_HOME/.cache/google-chrome" 2>/dev/null || true
    rm -rf "$USER_HOME/.cache/chromium" 2>/dev/null || true
    rm -rf "$USER_HOME/.local/share/Trash"/* 2>/dev/null || true
    find /tmp -user "$USERNAME" -type f -mmin +60 -delete 2>/dev/null || true
    rm -rf "$USER_HOME/.cache/thumbnails" 2>/dev/null || true
    echo ">>> [logoff] Limpeza concluida"

    # Remover atalhos temporarios do desktop
    if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
        for SHARE in $COMPARTILHAMENTOS; do
            rm -f "$USER_HOME/Desktop/${SHARE}.desktop" 2>/dev/null || true
        done
    fi

    # Salvar estado da sessao
    local LOG_DIR="/var/log/seederlinux"
    mkdir -p "$LOG_DIR"
    local LOG_FILE="${LOG_DIR}/session-${USERNAME}-$(date +%Y%m%d).log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logoff do usuario $USERNAME" >> "$LOG_FILE"
    find "$LOG_DIR" -name "session-*.log" -mtime +7 -delete 2>/dev/null || true

    # Encerrar processos do usuario
    killall -u "$USERNAME" conky 2>/dev/null || true
    killall -u "$USERNAME" x11vnc 2>/dev/null || true

    echo ">>> [logoff] Logoff concluido"
}

# ============================================================
# 1. Criar o script PERMANENTE em /usr/local/bin/seederlinux-logoff
# ============================================================
echo ">>> Criando script permanente: /usr/local/bin/seederlinux-logoff"

cat > /usr/local/bin/seederlinux-logoff <<'PERMSCRIPT'
#!/bin/bash
# seederlinux-logoff - Script permanente de logoff do SeederLinux
# Executado pelo display manager (LightDM/GDM3/SDDM) a cada logoff.
# Le as variaveis de /etc/seederlinux/config.env (persistente).

CONFIG_FILE="/etc/seederlinux/config.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo ">>> [logoff] AVISO: $CONFIG_FILE nao encontrado. Logoff sem configuracao."
    exit 0
fi

USERNAME="${USER:-$(whoami)}"
USER_HOME="${HOME:-/home/$USERNAME}"

echo ">>> [logoff] Usuario: $USERNAME"

# Desmontar compartilhamentos de rede
if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
    MOUNT_DIR="${MOUNT_BASE:-/mnt}"
    for SHARE in $COMPARTILHAMENTOS; do
        SHARE_MOUNT="${MOUNT_DIR}/${SHARE}"
        if mountpoint -q "$SHARE_MOUNT" 2>/dev/null; then
            umount "$SHARE_MOUNT" 2>/dev/null || {
                echo ">>> [logoff] AVISO: Falha ao desmontar ${SHARE_MOUNT}"
                umount -l "$SHARE_MOUNT" 2>/dev/null || true
            }
            echo ">>> [logoff] Compartilhamento desmontado: ${SHARE}"
        fi
    done
fi

# Limpar arquivos temporarios
rm -rf "$USER_HOME/.cache/mozilla" 2>/dev/null || true
rm -rf "$USER_HOME/.cache/google-chrome" 2>/dev/null || true
rm -rf "$USER_HOME/.cache/chromium" 2>/dev/null || true
rm -rf "$USER_HOME/.local/share/Trash"/* 2>/dev/null || true
find /tmp -user "$USERNAME" -type f -mmin +60 -delete 2>/dev/null || true
rm -rf "$USER_HOME/.cache/thumbnails" 2>/dev/null || true

# Remover atalhos temporarios
if [ -n "$COMPARTILHAMENTOS" ] && [ "$COMPARTILHAMENTOS" != "" ]; then
    for SHARE in $COMPARTILHAMENTOS; do
        rm -f "$USER_HOME/Desktop/${SHARE}.desktop" 2>/dev/null || true
    done
fi

# Salvar log de sessao
LOG_DIR="/var/log/seederlinux"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/session-${USERNAME}-$(date +%Y%m%d).log"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logoff do usuario $USERNAME" >> "$LOG_FILE"
find "$LOG_DIR" -name "session-*.log -mtime +7 -delete 2>/dev/null || true

# Encerrar processos do usuario
killall -U  "$USERNAME" conky 2>/dev/null || true
killall -u "$USERNAME" x11vnc 2>/dev/null || true

echo ">>> [logoff] Logoff concluido"
exit 0
PERMSCRIPT

chmod 755 /usr/local/bin/seederlinux-logoff
echo ">>> Script permanente criado: /usr/local/bin/seederlinux-logoff"

# ============================================================
# 2. Executar a logica de logoff AGORA (durante o bundle)
# ============================================================
echo ">>> Executando logica de logoff (bundle)..."
seederlinux_logoff "$COMPARTILHAMENTOS" "$MOUNT_BASE" "$DESKTOP_ENV"

echo ">>> [16] Logoff concluido!"
echo "============================================================"
