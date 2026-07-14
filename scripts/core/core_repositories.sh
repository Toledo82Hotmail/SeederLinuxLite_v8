#!/bin/bash
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
