#!/bin/bash
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
    alignment = 'top_right',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'grey',
    default_shade_color = 'grey',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    extra_newline = false,
    font = 'DejaVu Sans Mono:size=10',
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
    own_window_class = 'Conky',
    own_window_type = 'desktop',
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    show_graph_range = false,
    show_graph_scale = false,
    stippled_borders = 0,
    update_interval = 2.0,
    uppercase = false,
    use_spacer = 'none',
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
    alignment = 'top_right',
    background = false,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    font = 'DejaVu Sans Mono:size=10',
    gap_x = 10,
    gap_y = 30,
    minimum_width = 200,
    net_avg_samples = 2,
    no_buffers = true,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
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
cat > /usr/local/bin/seederlinux-conky <<'SCRIPT'
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
