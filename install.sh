#!/usr/bin/env bash
# Instala o widget no DankMaterialShell e o script de exportacao JSON.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
PLUGIN_DIR="$HOME/.config/DankMaterialShell/plugins/ClaudeUsage"

echo "==> Instalando dependencia claude-usage-tray (pip --user)"
python3 -m pip install --user --upgrade -r "$REPO_DIR/requirements.txt"

echo "==> Linkando script claude-usage-json em $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/bin/claude-usage-json" "$BIN_DIR/claude-usage-json"

echo "==> Linkando plugin do DankMaterialShell em $PLUGIN_DIR"
mkdir -p "$(dirname "$PLUGIN_DIR")"
ln -sfn "$REPO_DIR/dankmaterialshell/ClaudeUsage" "$PLUGIN_DIR"

cat <<'EOF'

Pronto. Falta so ativar o plugin:
  1. Abra as configuracoes do DankMaterialShell.
  2. Va em Plugins e habilite "Uso do Claude".
  3. Adicione o widget na barra (Bar > Widgets).

Se o Claude Code ainda nao estiver autenticado na maquina, rode `claude`
uma vez no terminal antes de usar o widget.
EOF
