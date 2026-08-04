#!/usr/bin/env bash
# Instala o widget no DankMaterialShell e o script de exportacao JSON.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
PLUGIN_DIR="$HOME/.config/DankMaterialShell/plugins/ClaudeUsage"

echo "==> Verificando dependencias"

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 nao encontrado. Instale Python 3.10+ e rode este script de novo." >&2
    exit 1
fi

PY_OK=$(python3 -c 'import sys; print(1 if sys.version_info >= (3, 10) else 0)')
if [ "$PY_OK" != "1" ]; then
    echo "Este projeto precisa de Python 3.10+; encontrado: $(python3 --version)." >&2
    exit 1
fi

if ! command -v quickshell >/dev/null 2>&1 && [ ! -d "$HOME/.config/DankMaterialShell" ]; then
    cat >&2 <<'EOF'
Aviso: nao encontrei o Quickshell nem uma instalacao do DankMaterialShell
(~/.config/DankMaterialShell). O widget so funciona dentro do DMS. Se ainda
nao instalou, veja: https://danklinux.com/docs/dankmaterialshell/installation
Continuando mesmo assim (o script Python funciona sozinho, sem o widget).
EOF
fi

echo "==> Instalando dependencia claude-usage-tray (pip --user)"
PIP_ERR="$(mktemp)"
trap 'rm -f "$PIP_ERR"' EXIT
if ! python3 -m pip install --user --upgrade -r "$REPO_DIR/requirements.txt" 2>"$PIP_ERR"; then
    if grep -qi "externally-managed-environment" "$PIP_ERR"; then
        echo "==> Ambiente Python gerenciado pela distro (PEP 668); tentando com --break-system-packages"
        python3 -m pip install --user --upgrade --break-system-packages -r "$REPO_DIR/requirements.txt"
    else
        cat "$PIP_ERR" >&2
        exit 1
    fi
fi

echo "==> Linkando script claude-usage-json em $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/bin/claude-usage-json" "$BIN_DIR/claude-usage-json"

echo "==> Linkando plugin do DankMaterialShell em $PLUGIN_DIR"
mkdir -p "$(dirname "$PLUGIN_DIR")"
if [ -e "$PLUGIN_DIR" ] && [ ! -L "$PLUGIN_DIR" ]; then
    BACKUP="$PLUGIN_DIR.bak-$(date +%Y%m%d%H%M%S)"
    echo "    Ja existe uma pasta (nao um link) em $PLUGIN_DIR; movendo para $BACKUP"
    mv "$PLUGIN_DIR" "$BACKUP"
fi
ln -sfn "$REPO_DIR/dankmaterialshell/ClaudeUsage" "$PLUGIN_DIR"

cat <<'EOF'

Pronto. Falta so ativar o plugin:
  1. Abra as configuracoes do DankMaterialShell.
  2. Va em Plugins e habilite "Uso do Claude".
  3. Adicione o widget na barra (Bar > Widgets).

Se o Claude Code ainda nao estiver autenticado na maquina, rode `claude`
uma vez no terminal antes de usar o widget.
EOF
