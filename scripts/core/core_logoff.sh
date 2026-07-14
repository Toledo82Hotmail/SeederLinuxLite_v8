#!/bin/bash
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
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logoff do usuario $USERNAME" >> "$LOG_FILE"

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
