# claude-usage-dank-widget

![tests](https://github.com/guedesarthurhenrique-cpu/claude-usage-dank-widget/actions/workflows/tests.yml/badge.svg)
![license](https://img.shields.io/badge/license-MIT-green.svg)
![python](https://img.shields.io/badge/python-3.10+-blue.svg)

Widget para o [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) que mostra,
direto na barra do seu desktop Linux, o uso do **Claude Code**: percentual das janelas de limite
(5 horas e 7 dias), quando cada uma reseta, custo equivalente em USD se você pagasse por API e uma
estimativa de quanto tempo o ritmo atual de uso ainda aguenta antes de bater no teto.

Desenvolvido e testado em Fedora Linux com Hyprland + DankMaterialShell; o script Python roda em
qualquer distro (veja [Instalação em outras distros](#instalação-em-outras-distros)).

## Sumário

- [Como funciona](#como-funciona)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Instalação em outras distros](#instalação-em-outras-distros)
- [Desinstalação](#desinstalação)
- [Solução de problemas](#solução-de-problemas)
- [Desenvolvimento e testes](#desenvolvimento-e-testes)
- [Créditos](#créditos)
- [Licença](#licença)

## Como funciona

- `bin/claude-usage-json` lê os dados locais do Claude Code e a API de uso da Anthropic (via o
  pacote [`claude-usage-tray`](#créditos)) e imprime um JSON com estatísticas, custo por modelo e
  a estimativa de ritmo.
- `dankmaterialshell/ClaudeUsage/` é um plugin do DankMaterialShell (QML) que chama esse script a
  cada 60s e renderiza o resultado na barra e num popout com o detalhamento por janela.

### Configurações (engrenagem no popout)

O ícone de engrenagem no cabeçalho do popout abre um painel com três opções, salvas nas
configurações do plugin (persistem entre reloads do DankMaterialShell):

- **Fazer login no Claude** — abre um terminal (detecta ghostty/alacritty/xterm/kitty/foot/wezterm,
  o que estiver instalado) rodando `claude auth login`, pra autenticar sem precisar sair do desktop
  pra abrir um terminal manualmente.
- **Tema** — alterna entre o tema padrão e o tema "Konoha": o ícone de raio na barra vira o selo da
  Vila da Folha (desenhado em QML puro com `Canvas`, sem imagem externa, respeitando as mesmas
  cores de status verde/amarelo/vermelho) e os textos do popout passam a falar de "chakra" em vez
  de "uso".
- **Idioma** — português ou inglês; troca todos os textos do popout (títulos, mensagens de erro,
  duração, custo), incluindo as variantes do tema Konoha em cada idioma.

### Estimativa de "quanto tempo dura nesse ritmo"

A cada execução o script guarda um pequeno histórico local de amostras (utilização × tempo) em
`~/.claude/usage-window-history.json` (escrita atômica — segura mesmo com múltiplos processos
lendo o mesmo script ao mesmo tempo). A duração estimada usa o ritmo **recente** de consumo
(últimos ~45 min para a janela de 5h, últimas ~24h para a de 7 dias) em vez da média desde a
abertura da janela — isso evita que horas ociosas no início da janela distorçam a projeção quando
você começa a usar pesado agora. Enquanto não há histórico suficiente (ex.: primeira execução, ou
logo após um reset de janela), o script cai de volta para a média desde o início da janela.

O widget mostra o resultado em minutos quando for menos de 1h (antes mostrava só "menos de 1h"
para qualquer coisa abaixo disso, o que desperdiçava a precisão do cálculo). O backend manda a
duração já em minutos inteiros (não mais arredondada pra 0.1h): antes disso, "dura Xh Ym nesse
ritmo" podia discordar em 1min de "reinicia em" pro mesmo reset, por causa de dois arredondamentos
em cascata (0.1h no backend, depois minutos de novo no QML). A formatação de "dura Xh Ym nesse
ritmo" também usa o mesmo corte para dias (24h) e o mesmo truncamento de horas que "reinicia em"
usa — antes o corte era 48h, então durações entre 24h e 48h apareciam como "30h" num texto e
"1d 6h" no outro para o mesmo evento de reset.

## Requisitos

- Linux com [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) instalado e
  funcionando (Quickshell).
- Python 3.10+
- Claude Code autenticado na máquina (`claude` no terminal ao menos uma vez).

## Instalação

```bash
git clone https://github.com/guedesarthurhenrique-cpu/claude-usage-dank-widget.git
cd claude-usage-dank-widget
./install.sh
```

O script:
1. Confere se você tem Python 3.10+ e (se possível) se o DankMaterialShell está instalado.
2. Instala a dependência `claude-usage-tray` via `pip install --user` — se a sua distro bloquear
   pip fora de venv (PEP 668 / `externally-managed-environment`), o script detecta isso sozinho e
   refaz a instalação com `--break-system-packages`.
3. Cria um link simbólico de `bin/claude-usage-json` em `~/.local/bin`.
4. Cria um link simbólico da pasta do plugin em `~/.config/DankMaterialShell/plugins/ClaudeUsage`
   (se já existir uma pasta de verdade nesse lugar, ela é renomeada como backup em vez de
   sobrescrita).

Depois, abra as configurações do DankMaterialShell, habilite o plugin "Uso do Claude" em Plugins
e adicione o widget na barra.

## Instalação em outras distros

O DankMaterialShell tem instalador oficial multi-distro:

```bash
curl -fsSL https://install.danklinux.com | sh
```

Cobre Arch, Fedora, Debian, Ubuntu, openSUSE e Gentoo; NixOS tem um flake próprio (veja o
[guia de instalação](https://danklinux.com/docs/dankmaterialshell/installation)). O DMS funciona
melhor com niri ou Hyprland, mas também roda em Sway, MangoWC, labwc, Scroll e Miracle WM.

Com o DMS instalado, o `install.sh` deste repositório funciona igual em qualquer uma dessas
distros — a única diferença entre elas é como o `pip` se comporta:

| Distro | Comportamento do `pip install --user` |
|---|---|
| Fedora | Funciona direto, sem flags extra. |
| Debian / Ubuntu / Arch / openSUSE (recentes) | Bloqueado por padrão (PEP 668). O `install.sh` detecta o erro `externally-managed-environment` e tenta de novo com `--break-system-packages` automaticamente. |
| NixOS | `pip install --user` normalmente não é o caminho idiomático em NixOS. Se preferir, crie um venv (`python3 -m venv .venv && source .venv/bin/activate`) antes de rodar `./install.sh`, ou instale `claude-usage-tray` via `nix-shell -p python3Packages.pip` seguido do mesmo `pip install`. |

## Desinstalação

```bash
rm ~/.local/bin/claude-usage-json
rm ~/.config/DankMaterialShell/plugins/ClaudeUsage
python3 -m pip uninstall claude-usage-tray
```

## Solução de problemas

- **"Sign in to Claude Code first"** no popout do widget — rode `claude` no terminal para
  autenticar antes de usar o widget.
- **Widget não aparece nas configurações do DMS** — confira se o link simbólico existe
  (`ls -la ~/.config/DankMaterialShell/plugins/ClaudeUsage`) e se a versão do DMS é `>=1.5.0`
  (requisito declarado em `dankmaterialshell/ClaudeUsage/plugin.json`).
- **`error: externally-managed-environment` ao rodar `install.sh` manualmente com outro comando**
  — use `pip install --user --break-system-packages -r requirements.txt`, ou instale dentro de um
  venv.
- **Estimativa de tempo ainda meio imprecisa logo após instalar** — é esperado: o cálculo de ritmo
  recente só entra em ação depois de ter uns minutos de histórico acumulado (~8min para a janela
  de 5h). Antes disso ele usa a média desde o início da janela, que é menos precisa.
- **Editei o `.qml` e a mudança não aparece no widget** — `dms ipc call plugins reload <id>` **não**
  recompila o QML, só reprocessa metadata do plugin. Quem recompila de verdade é
  `dms ipc call plugin-scan reload <id>` (nota: alvo `plugin-scan`, não `plugins`) — internamente
  ele força um `Qt.createComponent` com cache-busting. Um `dms restart` completo também funciona,
  mas é bem mais lento e derruba a barra inteira por um instante; prefira o `plugin-scan reload`
  pra iterar. Isso vale pra qualquer alteração de código do widget, não só as deste repo.

## Desenvolvimento e testes

```bash
python3 -m pip install -r requirements-dev.txt
python3 -m pytest tests/ -v
```

Os testes cobrem a lógica de estimativa de ritmo (`calcular_duracao_ritmo`), o histórico local
(poda de amostras antigas, reset ao trocar de janela, robustez a relógio do sistema voltando no
tempo) e a tabela de preços. Rodam em CI a cada push/PR (Python 3.10, 3.12 e 3.13).

## Créditos

A leitura dos dados brutos de uso (sessões locais do Claude Code + API OAuth de uso da Anthropic)
usa como biblioteca o pacote [`claude-usage-tray`](https://github.com/Bortlesboat/claude-usage-monitor),
de Andrew Barnes, distribuído via PyPI sob licença MIT. Este repositório não redistribui o código
dele — apenas depende dele (`requirements.txt`) e adiciona por cima o exportador JSON com custo em
USD, breakdown por modelo e a estimativa de ritmo, além do widget de integração com o
DankMaterialShell.

## Licença

MIT — veja [LICENSE](LICENSE). Cobre apenas o código deste repositório (`bin/`, `tests/` e
`dankmaterialshell/`); o `claude-usage-tray` tem sua própria licença MIT, do autor original.
