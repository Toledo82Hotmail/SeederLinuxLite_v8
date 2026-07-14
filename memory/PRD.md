# SeederLinux Lite — Bundle Generator PRD

## Original Problem Statement
Corrigir 6 problemas técnicos + 1 problema de arquitetura no gerador de bundle do SeederLinux Lite:
1. `{DC_IP_LIST}` e `{ADMIN_USERNAME}` não substituídos.
2. Erro de sintaxe `$DNS_SECUNDARIO}` em core_dns.sh.
3. `winbind offline logon = false` hardcoded em core_domain.sh.
4. Três scripts de sessão (14a/14b/14c) sempre incluídos no bundle — deveria ser apenas UM.
5. Arquitetura: o bundle instala DE ao invés de detectar o já instalado.

## Tech Stack
- Backend: PHP + PostgreSQL (não React/FastAPI)
- Frontend: HTML/JS estático (admin.html, login.html)
- Bundle-gen: scripts bash com placeholders `{{VAR}}` substituídos server-side.

## What's Implemented (2026-01)
- **install/schema.sql**: adicionadas 3 novas `variable_definitions` — `DC_IP_LIST`, `ADMIN_USERNAME`, `INSTALL_DESKTOP`. `DESKTOP_ENV` e `DISPLAY_MANAGER` agora têm default vazio (detecção automática). Seed explícito ON CONFLICT DO NOTHING para garantir presença dessas variáveis para org 1 (COMARA).
- **scripts/core/core_dns.sh**: corrigido `$DNS_SECUNDARIO}` → `${DNS_SECUNDARIO}`.
- **scripts/core/core_domain.sh**: adicionada var `AUTH_METHOD`; `winbind offline logon` agora usa `${WINBIND_OFFLINE}` calculado dinamicamente conforme `AUTH_METHOD` e `OFFLINE_AUTH_ENABLED`.
- **scripts/core/core_packages.sh**: removida instalação obrigatória de DE. Adicionadas funções `detectar_de()` / `detectar_dm()` exportando `DETECTED_DE` / `DETECTED_DM`. Instalação de DE só ocorre se `INSTALL_DESKTOP=true`.
- **scripts/core/core_branding.sh**: fallback automático para detectar `DESKTOP_ENV` e `DISPLAY_MANAGER` quando não fornecidos.
- **scripts/core/core_session_lightdm.sh, core_session_gdm3.sh, core_session_sddm.sh**: fallback automático para detectar `DISPLAY_MANAGER` via `systemctl is-active` + `/etc/X11/default-display-manager`.
- **scripts/core/core_logon.sh, core_logoff.sh**: fallback automático para detectar `DESKTOP_ENV`.
- **api/index.php `handleGenerateBundle()`**: agora carrega `DISPLAY_MANAGER` das variáveis da OM, mapeia para o script de sessão correspondente (`lightdm`/`gdm3`/`sddm`), e filtra `array_filter` para incluir apenas o script correto (fallback `lightdm`). Preserva todos os outros scripts.

## Verified
- Todos os arquivos PHP passam `php -l`.
- Todos os scripts bash passam `bash -n`.
- Simulação de substituição PHP confirmou: `DC_IP_LIST` e `ADMIN_USERNAME` substituídos; sintaxe DNS_SECUNDARIO correta; winbind condicional aplicado.
- Simulação do filtro `handleGenerateBundle` confirmou: para cada valor de `DISPLAY_MANAGER` (lightdm/gdm3/sddm/vazio/desconhecido), apenas o script correspondente é mantido, e fallback lightdm funciona.

## Files Modified (Escopo Restrito)
- install/schema.sql
- api/index.php (apenas handleGenerateBundle)
- scripts/core/core_dns.sh
- scripts/core/core_domain.sh
- scripts/core/core_packages.sh
- scripts/core/core_branding.sh
- scripts/core/core_session_lightdm.sh
- scripts/core/core_session_gdm3.sh
- scripts/core/core_session_sddm.sh
- scripts/core/core_logon.sh
- scripts/core/core_logoff.sh

Não foram alterados: lib/config.php, admin.html, admin.js, login.html, lib/functions.php (o `substituir_placeholders` já usa `str_replace` puro sem regex; nomes com underscore/dígitos funcionam).

## Backlog / Nice-to-have
- Testar bundle real em VM Debian/Ubuntu/Mint/Zorin com diferentes DEs.
- Adicionar UI no admin.html para toggle `INSTALL_DESKTOP` e seleção condicional de `DESKTOP_ENV`.
- Adicionar validação no bundle: se `INSTALL_DESKTOP=false` e nenhum DE detectado, avisar/abortar.
