# claude-usage-dank-widget

Widget para o [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) que mostra,
direto na barra do seu desktop Linux, o uso do **Claude Code**: percentual das janelas de limite
(5 horas e 7 dias), quando cada uma reseta, custo equivalente em USD se voce pagasse por API e uma
estimativa de quanto tempo o ritmo atual de uso ainda aguenta antes de bater no teto.

Testado em Fedora Linux com Hyprland + DankMaterialShell.

## Como funciona

- `bin/claude-usage-json` le os dados locais do Claude Code e da API de uso da Anthropic (via o
  pacote [`claude-usage-tray`](#creditos)) e imprime um JSON com estatisticas, custo por modelo e
  a estimativa de ritmo.
- `dankmaterialshell/ClaudeUsage/` e um plugin do DankMaterialShell (QML) que chama esse script a
  cada 60s e renderiza o resultado na barra e num popout com o detalhamento por janela.

### Estimativa de "quanto tempo dura nesse ritmo"

A cada execucao o script guarda um pequeno historico local de amostras (utilizacao x tempo) em
`~/.claude/usage-window-history.json`. A duracao estimada usa o ritmo **recente** de consumo
(ultimos ~45min para a janela de 5h, ultimas ~24h para a de 7 dias) em vez da media desde a
abertura da janela — o que evita que horas ociosas no inicio da janela distorçam a projecao quando
voce começa a usar pesado agora. Enquanto nao ha historico suficiente (ex.: primeira execucao),
cai de volta para a media desde o inicio da janela.

## Requisitos

- Linux com [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) instalado e
  funcionando (Quickshell).
- Python 3.10+
- Claude Code autenticado na maquina (`claude` no terminal ao menos uma vez).

## Instalacao

```bash
git clone https://github.com/<seu-usuario>/claude-usage-dank-widget.git
cd claude-usage-dank-widget
./install.sh
```

O script:
1. Instala a dependencia `claude-usage-tray` via `pip install --user`.
2. Cria um link simbolico de `bin/claude-usage-json` em `~/.local/bin`.
3. Cria um link simbolico da pasta do plugin em `~/.config/DankMaterialShell/plugins/ClaudeUsage`.

Depois, abra as configuracoes do DankMaterialShell, habilite o plugin "Uso do Claude" em Plugins
e adicione o widget na barra.

## Desinstalacao

```bash
rm ~/.local/bin/claude-usage-json
rm ~/.config/DankMaterialShell/plugins/ClaudeUsage
python3 -m pip uninstall claude-usage-tray
```

## Creditos

A leitura dos dados brutos de uso (sessoes locais do Claude Code + API OAuth de uso da Anthropic)
usa como biblioteca o pacote [`claude-usage-tray`](https://github.com/Bortlesboat/claude-usage-monitor),
de Andrew Barnes, distribuido via PyPI sob licenca MIT. Este repositorio nao redistribui o codigo
dele — apenas depende dele (`requirements.txt`) e adiciona por cima o exportador JSON com custo em
USD, breakdown por modelo e a estimativa de ritmo, alem do widget de integracao com o
DankMaterialShell.

## Licenca

MIT — veja [LICENSE](LICENSE). Cobre apenas o codigo deste repositorio (`bin/` e
`dankmaterialshell/`); o `claude-usage-tray` tem sua propria licenca MIT, do autor original.
