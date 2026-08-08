import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string home: Paths.strip(Paths.home)
    readonly property string scriptPath: home + "/.local/bin/claude-usage-json"

    property var stats: ({})
    property bool loading: true
    property bool failed: false
    property bool mostrarConfig: false

    readonly property var janelas: stats.live_windows || []
    readonly property real pctPrincipal: {
        if (janelas.length === 0)
            return stats.usage_pct !== undefined ? stats.usage_pct : 0;
        let maior = 0;
        for (let i = 0; i < janelas.length; i++)
            maior = Math.max(maior, janelas[i].utilization || 0);
        return maior;
    }
    readonly property color corPrincipal: root.corPara(pctPrincipal)

    // Tema visual ("default"/"naruto") e idioma ("pt"/"en"), persistidos nas
    // configuracoes do plugin -- sobrevivem a reloads do DankMaterialShell.
    readonly property bool temaNaruto: root.pluginData && root.pluginData.tema === "naruto"
    readonly property string idioma: (root.pluginData && root.pluginData.idioma) || "pt"

    function alternarTema() {
        if (!root.pluginService)
            return;
        root.pluginService.savePluginData(root.pluginId, "tema", root.temaNaruto ? "default" : "naruto");
    }

    function alternarIdioma() {
        if (!root.pluginService)
            return;
        root.pluginService.savePluginData(root.pluginId, "idioma", root.idioma === "en" ? "pt" : "en");
    }

    // Abre um terminal rodando "claude auth login" -- tenta os emuladores
    // mais comuns em ordem ate achar um instalado. Fica com o terminal
    // aberto depois do comando pra dar tempo de ler erro/confirmacao.
    function fazerLogin() {
        const inner = "claude auth login; echo; read -p \"" + root.t.loginPrompt + "\" _";
        const script = ["inner='" + inner + "'", "for t in ghostty alacritty xterm; do command -v \"$t\" >/dev/null 2>&1 && exec \"$t\" -e sh -c \"$inner\"; done", "for t in kitty foot; do command -v \"$t\" >/dev/null 2>&1 && exec \"$t\" sh -c \"$inner\"; done", "command -v wezterm >/dev/null 2>&1 && exec wezterm start -- sh -c \"$inner\"", "command -v notify-send >/dev/null 2>&1 && notify-send 'Claude' 'Nenhum terminal encontrado. Rode: claude auth login'"].join(" ; ");
        Quickshell.execDetached(["sh", "-c", script]);
        ToastService.showInfo(root.t.loginToast);
    }

    // Textos da UI por idioma; quando o tema Konoha esta ativo, algumas
    // chaves (header, falha, semDados, reinicia, custoMeio, duracao*) sao
    // trocadas pela versao "chakra". O resto (botoes, configuracoes) fica
    // igual nos dois temas.
    readonly property var t: root.idioma === "en" ? ({
        header: root.temaNaruto ? "Chakra" : "Claude",
        falha: root.temaNaruto ? "The seal broke — couldn't sense any chakra." : "Could not read usage data.",
        semDados: root.temaNaruto ? "No chakra being spent right now." : "No usage data right now.",
        reinicia: root.temaNaruto ? "chakra recharges in " : "resets in ",
        custoMeio: root.temaNaruto ? " in chakra via API  ·  seal costs " : " via API  ·  plan ",
        porMes: "/mo",
        menosDeUm: "less than 1m",
        configuracoes: "Settings",
        atualizar: "Refresh",
        voltar: "Back",
        login: "Sign in to Claude",
        loginDesc: "Opens a terminal to authenticate with your Anthropic account.",
        loginToast: "Opening a terminal to sign in…",
        loginPrompt: "Press Enter to close...",
        tema: "Theme",
        temaPadrao: "Default",
        temaKonoha: "Konoha",
        idiomaLabel: "Language",
        duracaoCap: d => root.temaNaruto ? ("chakra runs out in " + d + " — won't last until recharge") : ("runs out in " + d + " — won't make it to reset"),
        duracaoRitmo: d => root.temaNaruto ? ("lasts " + d + " at this pace — makes it to the recharge") : ("lasts " + d + " at this pace — makes it to reset")
    }) : ({
        header: root.temaNaruto ? "Chakra" : "Claude",
        falha: root.temaNaruto ? "O selo caiu — não foi possível sentir o chakra." : "Não foi possível ler os dados de uso.",
        semDados: root.temaNaruto ? "Nenhum chakra sendo gasto no momento." : "Sem dados de uso no momento.",
        reinicia: root.temaNaruto ? "chakra recarrega em " : "reinicia em ",
        custoMeio: root.temaNaruto ? " em chakra via API  ·  selo custa " : " via API  ·  plano ",
        porMes: "/mês",
        menosDeUm: "menos de 1m",
        configuracoes: "Configurações",
        atualizar: "Atualizar",
        voltar: "Voltar",
        login: "Fazer login no Claude",
        loginDesc: "Abre um terminal para autenticar com sua conta Anthropic.",
        loginToast: "Abrindo terminal para login…",
        loginPrompt: "Pressione Enter para fechar...",
        tema: "Tema",
        temaPadrao: "Padrão",
        temaKonoha: "Konoha",
        idiomaLabel: "Idioma",
        duracaoCap: d => root.temaNaruto ? ("o chakra acaba em " + d + " — não aguenta até a recarga") : ("acaba em " + d + " — não chega no reset"),
        duracaoRitmo: d => root.temaNaruto ? ("aguenta " + d + " nesse ritmo — chega na recarga") : ("dura " + d + " nesse ritmo — chega no reset")
    })

    function corPara(pct) {
        if (pct >= 90)
            return Theme.error;
        if (pct >= 65)
            return "#f2cc8f";
        return root.temaNaruto ? "#ff7800" : Theme.primary;
    }

    // Simbolo da Vila da Folha desenhado em Canvas -- fica no lugar do
    // icone de raio quando o tema "naruto" esta ativo, e aceita a mesma
    // cor de status (verde/amarelo/vermelho) que o raio usava.
    component KonohaIcon: Canvas {
        id: konohaRoot
        property color corIcone: Theme.primary

        onCorIconeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const cx = w / 2, cy = h / 2;
            const raio = Math.min(w, h) / 2 - Math.max(1, w * 0.08);

            ctx.strokeStyle = konohaRoot.corIcone;
            ctx.lineWidth = Math.max(1, w * 0.12);
            ctx.beginPath();
            ctx.arc(cx, cy, raio, 0, Math.PI * 2);
            ctx.stroke();

            ctx.fillStyle = konohaRoot.corIcone;
            ctx.save();
            ctx.translate(cx, cy);
            const s = raio * 0.8;
            ctx.beginPath();
            ctx.moveTo(0, -s);
            ctx.bezierCurveTo(s * 0.78, -s * 0.78, s * 0.62, -s * 0.05, 0, 0);
            ctx.bezierCurveTo(-s * 0.62, s * 0.05, -s * 0.78, s * 0.78, 0, s);
            ctx.bezierCurveTo(s * 0.32, s * 0.5, s * 0.3, s * 0.12, 0, 0);
            ctx.bezierCurveTo(-s * 0.3, -s * 0.12, -s * 0.32, -s * 0.5, 0, -s);
            ctx.closePath();
            ctx.fill();
            ctx.restore();
        }
    }

    function formatarUsd(v) {
        if (v === undefined || v === null)
            return "$0";
        return "$" + v.toFixed(v >= 10 ? 0 : 2);
    }

    function formatarDuracao(minutos) {
        // O backend ja manda o total em minutos inteiros (mesma precisao
        // que resets_in usa) -- arredondar de novo aqui a partir de horas
        // fazia "dura Xh Ym" discordar de "reinicia em" por causa de
        // arredondamentos em cascata (ex.: 1h 42m vs 1h 43m pro mesmo
        // reset). Mesmo corte (24h) e mesmo truncamento (nao arredondamento)
        // de horas que resets_in_display usa na claude-usage-tray -- um
        // corte de 48h aqui fazia durações entre 24h-48h aparecerem como
        // "30h" enquanto "reinicia em" mostrava "1d 6h" pro mesmo evento.
        if (minutos === undefined || minutos === null)
            return "";
        const totalMin = Math.round(minutos);
        if (totalMin <= 0)
            return root.t.menosDeUm;
        if (totalMin < 60)
            return totalMin + "m";
        const horas = Math.floor(totalMin / 60);
        const m = totalMin % 60;
        if (horas < 24)
            return m === 0 ? horas + "h" : horas + "h " + m + "m";
        const dias = Math.floor(horas / 24);
        const horasResto = horas % 24;
        return horasResto === 0 ? dias + "d" : dias + "d " + horasResto + "h";
    }

    function atualizar() {
        Proc.runCommand("claudeUsage.refresh", [root.scriptPath], (stdout, exitCode) => {
            if (exitCode === 0) {
                try {
                    root.stats = JSON.parse(stdout);
                    root.failed = false;
                } catch (e) {
                    root.failed = true;
                }
            } else {
                root.failed = true;
            }
            root.loading = false;
        });
    }

    Component.onCompleted: atualizar()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.atualizar()
    }

    popoutWidth: 340
    popoutHeight: 260

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                visible: !root.temaNaruto
                name: "bolt"
                size: root.iconSize
                color: root.loading ? Theme.surfaceText : root.corPrincipal
                anchors.verticalCenter: parent.verticalCenter
            }

            KonohaIcon {
                visible: root.temaNaruto
                width: root.iconSize
                height: root.iconSize
                corIcone: root.loading ? Theme.surfaceText : root.corPrincipal
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.loading ? "…" : (root.failed ? "?" : Math.round(root.pctPrincipal) + "%")
                color: root.loading ? Theme.surfaceText : root.corPrincipal
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                visible: !root.temaNaruto
                name: "bolt"
                size: root.iconSize
                color: root.loading ? Theme.surfaceText : root.corPrincipal
                anchors.horizontalCenter: parent.horizontalCenter
            }

            KonohaIcon {
                visible: root.temaNaruto
                width: root.iconSize
                height: root.iconSize
                corIcone: root.loading ? Theme.surfaceText : root.corPrincipal
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.loading ? "…" : (root.failed ? "?" : Math.round(root.pctPrincipal) + "%")
                color: root.loading ? Theme.surfaceText : root.corPrincipal
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: root.mostrarConfig ? root.t.configuracoes : root.t.header
            showCloseButton: true

            headerActions: Component {
                Row {
                    spacing: Theme.spacingXS

                    DankActionButton {
                        iconName: root.mostrarConfig ? "arrow_back" : "settings"
                        buttonSize: 26
                        iconSize: 15
                        tooltipText: root.mostrarConfig ? root.t.voltar : root.t.configuracoes
                        onClicked: root.mostrarConfig = !root.mostrarConfig
                    }

                    DankActionButton {
                        iconName: "refresh"
                        buttonSize: 26
                        iconSize: 15
                        tooltipText: root.t.atualizar
                        onClicked: root.atualizar()
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.spacingM
            }

            StyledText {
                width: parent.width
                visible: !root.mostrarConfig && root.failed
                text: root.t.falha
                color: Theme.error
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                visible: !root.mostrarConfig && !root.failed && root.janelas.length === 0
                // stats.live_error ja traz a mensagem certa por caso (nao
                // logado, rate limited, sem rede, sessao expirada, etc.) --
                // mostrar um "faca login" fixo aqui confundia num rate
                // limit transitorio, que nao tem nada a ver com login.
                text: root.stats.live_error || root.t.semDados
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                visible: !root.mostrarConfig && !root.failed && root.janelas.length > 0
                spacing: Theme.spacingL

                Repeater {
                    model: root.janelas

                    delegate: Column {
                        required property var modelData
                        width: parent.width
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 22

                            StyledText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeMedium
                            }

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                DankIcon {
                                    visible: !!modelData.limited_by
                                    name: modelData.limited_by === "cap" ? "error" : "check_circle"
                                    size: 16
                                    color: modelData.limited_by === "cap" ? Theme.error : "#7fb069"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: modelData.utilization.toFixed(0) + "%"
                                    color: root.corPara(modelData.utilization)
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 4
                            radius: 2
                            color: Theme.surfaceContainerHigh

                            Rectangle {
                                width: parent.width * Math.min(modelData.utilization / 100, 1)
                                height: parent.height
                                radius: 2
                                color: root.corPara(modelData.utilization)
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: modelData.duration_minutes !== undefined && modelData.duration_minutes !== null
                            text: modelData.limited_by === "cap" ? root.t.duracaoCap(root.formatarDuracao(modelData.duration_minutes)) : root.t.duracaoRitmo(root.formatarDuracao(modelData.duration_minutes))
                            color: modelData.limited_by === "cap" ? Theme.error : "#7fb069"
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        StyledText {
                            width: parent.width
                            visible: !!modelData.resets_in
                            text: root.t.reinicia + modelData.resets_in
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                            opacity: 0.7
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.spacingM
                visible: !root.mostrarConfig && !root.failed
            }

            StyledText {
                width: parent.width
                visible: !root.mostrarConfig && !root.failed && root.stats.api_equivalent_cost_usd !== undefined
                text: root.formatarUsd(root.stats.api_equivalent_cost_usd) + root.t.custoMeio + root.formatarUsd(root.stats.plan_price_usd) + root.t.porMes
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Column {
                width: parent.width
                visible: root.mostrarConfig
                spacing: Theme.spacingL

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: Theme.cornerRadius
                    color: loginArea.containsMouse ? Theme.primaryHover : Theme.surfaceContainerHigh

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "login"
                            size: 18
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: root.t.login
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: loginArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fazerLogin()
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.t.loginDesc
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.3
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: root.t.tema
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        spacing: Theme.spacingXS

                        Repeater {
                            model: [{
                                rotulo: root.t.temaPadrao,
                                ativo: !root.temaNaruto
                            }, {
                                rotulo: root.t.temaKonoha,
                                ativo: root.temaNaruto
                            }]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                height: 30
                                width: chipTexto.implicitWidth + Theme.spacingM * 2
                                radius: height / 2
                                color: modelData.ativo ? Theme.primary : Theme.surfaceContainerHigh
                                border.width: modelData.ativo ? 0 : 1
                                border.color: Theme.outline

                                StyledText {
                                    id: chipTexto
                                    anchors.centerIn: parent
                                    text: modelData.rotulo
                                    color: modelData.ativo ? Theme.primaryText : Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!modelData.ativo)
                                            root.alternarTema();
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    StyledText {
                        text: root.t.idiomaLabel
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        spacing: Theme.spacingXS

                        Repeater {
                            model: [{
                                rotulo: "Português",
                                ativo: root.idioma === "pt"
                            }, {
                                rotulo: "English",
                                ativo: root.idioma === "en"
                            }]

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                height: 30
                                width: idiomaTexto.implicitWidth + Theme.spacingM * 2
                                radius: height / 2
                                color: modelData.ativo ? Theme.primary : Theme.surfaceContainerHigh
                                border.width: modelData.ativo ? 0 : 1
                                border.color: Theme.outline

                                StyledText {
                                    id: idiomaTexto
                                    anchors.centerIn: parent
                                    text: modelData.rotulo
                                    color: modelData.ativo ? Theme.primaryText : Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!modelData.ativo)
                                            root.alternarIdioma();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
