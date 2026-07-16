#!/bin/bash
# ============================================================================
# Core Script: core_repositories.sh
# SeederLinux Lite - Configurar sources.list (APT)
# ============================================================================
# Detecta a distribuição (Debian, Ubuntu, Mint, Zorin) e configura os
# repositórios APT conforme o modo: PUBLIC (padrão da distro), MIRROR
# (espelho local), HYBRID (espelho + fallback) ou CUSTOM (URL personalizada).
# NUNCA altera sources.list se o modo for PUBLIC ou se não houver mirror.
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

echo ">>> Modo de repositorio: $REPOSITORY_MODE"

# ============================================================
# Detectar a distribuição
# ============================================================
detect_distro() {
    if [ -f /etc/linuxmint/info ]; then
        echo "mint"
    elif [ -f /etc/zorin-release ]; then
        echo "zorin"
    elif grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        echo "ubuntu"
    elif grep -qi "debian" /etc/os-release 2>/dev/null; then
        echo "debian"
    else
        echo "unknown"
    fi
}

DISTRO=$(detect_distro)
echo ">>> Distribuição detectada: $DISTRO"

# ============================================================
# Backup do sources.list original (antes de qualquer alteração)
# ============================================================
backup_sources() {
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)
        echo ">>> Backup do sources.list criado"
    fi
}

# ============================================================
# Obter codename da distro
# ============================================================
get_codename() {
    lsb_release -cs 2>/dev/null || echo "$1"
}

# ============================================================
# Configuração conforme o modo
# ============================================================
case "$REPOSITORY_MODE" in
    PUBLIC|"")
        echo ">>> Modo PUBLIC: mantendo repositorios padrao da distribuicao ($DISTRO)."
        echo ">>> Nenhuma alteracao em sources.list foi feita."
        ;;

    MIRROR)
        if [ -z "$REPOSITORY_URL" ] || [ "$REPOSITORY_URL" = "" ]; then
            echo ">>> Nenhum mirror definido. Mantendo sources.list padrao."
            exit 0
        fi

        echo ">>> Configurando repositorio espelho: $REPOSITORY_URL"
        backup_sources

        case "$DISTRO" in
            debian)
                DEBIAN_CODENAME=$(get_codename trixie)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/debian $DEBIAN_CODENAME main contrib non-free non-free-firmware
deb $REPOSITORY_URL/debian-security $DEBIAN_CODENAME-security main contrib non-free non-free-firmware
deb $REPOSITORY_URL/debian $DEBIAN_CODENAME-updates main contrib non-free non-free-firmware
EOF
                ;;
            ubuntu)
                UBUNTU_CODENAME=$(get_codename noble)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                ;;
            mint)
                MINT_CODENAME=$(get_codename wilma)
                UBUNTU_CODENAME=$(grep UBUNTU_CODENAME /etc/linuxmint/info 2>/dev/null | cut -d= -f2 || echo noble)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/mint $MINT_CODENAME main upstream import backport
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                ;;
            zorin)
                UBUNTU_CODENAME=$(get_codename jammy)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                ;;
            *)
                echo ">>> Distribuicao nao reconhecida. Mantendo sources.list padrao."
                ;;
        esac
        ;;

    HYBRID)
        if [ -z "$REPOSITORY_URL" ] || [ "$REPOSITORY_URL" = "" ]; then
            echo ">>> Nenhum mirror definido para modo HYBRID. Mantendo sources.list padrao."
            exit 0
        fi

        echo ">>> Configurando repositorio hibrido (espelho + fallback)"
        backup_sources

        case "$DISTRO" in
            debian)
                DEBIAN_CODENAME=$(get_codename trixie)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/debian $DEBIAN_CODENAME main contrib non-free non-free-firmware
deb $REPOSITORY_URL/debian-security $DEBIAN_CODENAME-security main contrib non-free non-free-firmware
deb $REPOSITORY_URL/debian $DEBIAN_CODENAME-updates main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK/debian $DEBIAN_CODENAME main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK/debian-security $DEBIAN_CODENAME-security main contrib non-free non-free-firmware
deb $REPOSITORY_FALLBACK/debian $DEBIAN_CODENAME-updates main contrib non-free non-free-firmware
EOF
                ;;
            ubuntu)
                UBUNTU_CODENAME=$(get_codename noble)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                ;;
            mint)
                MINT_CODENAME=$(get_codename wilma)
                UBUNTU_CODENAME=$(grep UBUNTU_CODENAME /etc/linuxmint/info 2>/dev/null | cut -d= -f2 || echo noble)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/mint $MINT_CODENAME main upstream import backport
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
deb $REPOSITORY_FALLBACK/mint $MINT_CODENAME main upstream import backport
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                ;;
            zorin)
                UBUNTU_CODENAME=$(get_codename jammy)
                cat > /etc/apt/sources.list <<EOF
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_URL/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $REPOSITORY_FALLBACK/ubuntu $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
                ;;
            *)
                echo ">>> Distribuicao nao reconhecida. Mantendo sources.list padrao."
                ;;
        esac
        ;;

    CUSTOM)
        if [ -z "$REPOSITORY_URL" ] || [ "$REPOSITORY_URL" = "" ]; then
            echo ">>> ERRO: REPOSITORY_URL nao definido para modo CUSTOM"
            exit 1
        fi

        echo ">>> Configurando repositorio personalizado"
        backup_sources

        cat > /etc/apt/sources.list <<EOF
$REPOSITORY_URL
EOF
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
