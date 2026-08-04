import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string home: Paths.strip(Paths.home)
    readonly property string scriptPath: home + "/.local/bin/claude-usage-json"

    property var stats: ({})
    property bool loading: true
    property bool failed: false

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

    function corPara(pct) {
        return pct >= 90 ? Theme.error : (pct >= 65 ? "#f2cc8f" : Theme.primary);
    }

    function formatarUsd(v) {
        if (v === undefined || v === null)
            return "$0";
        return "$" + v.toFixed(v >= 10 ? 0 : 2);
    }

    function formatarDuracao(horas) {
        // O backend ja calcula com precisao de 0.1h (~6min); antes essa
        // funcao jogava tudo fora arredondando pra hora cheia (ex.: 4.6h
        // virava "~5h"). Mesmo formato Xh Ym / Xd Yh que resets_in ja usa.
        if (horas === undefined || horas === null)
            return "";
        const totalMin = Math.round(horas * 60);
        if (totalMin <= 0)
            return "menos de 1m";
        if (totalMin < 60)
            return totalMin + "m";
        if (horas < 48) {
            const h = Math.floor(totalMin / 60);
            const m = totalMin % 60;
            return m === 0 ? h + "h" : h + "h " + m + "m";
        }
        const totalHoras = Math.round(horas);
        const dias = Math.floor(totalHoras / 24);
        const horasResto = totalHoras % 24;
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
                name: "bolt"
                size: root.iconSize
                color: root.loading ? Theme.surfaceText : root.corPrincipal
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
                name: "bolt"
                size: root.iconSize
                color: root.loading ? Theme.surfaceText : root.corPrincipal
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
            headerText: "Claude"
            showCloseButton: true

            headerActions: Component {
                DankActionButton {
                    iconName: "refresh"
                    buttonSize: 26
                    iconSize: 15
                    tooltipText: "Atualizar"
                    onClicked: root.atualizar()
                }
            }

            Item {
                width: parent.width
                height: Theme.spacingM
            }

            StyledText {
                width: parent.width
                visible: root.failed
                text: "Não foi possível ler os dados de uso."
                color: Theme.error
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                visible: !root.failed && root.janelas.length === 0
                // stats.live_error ja traz a mensagem certa por caso (nao
                // logado, rate limited, sem rede, sessao expirada, etc.) --
                // mostrar um "faca login" fixo aqui confundia num rate
                // limit transitorio, que nao tem nada a ver com login.
                text: root.stats.live_error || "Sem dados de uso no momento."
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                visible: !root.failed && root.janelas.length > 0
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
                            visible: modelData.duration_hours !== undefined && modelData.duration_hours !== null
                            text: modelData.limited_by === "cap" ? "acaba em " + root.formatarDuracao(modelData.duration_hours) + " — não chega no reset" : "dura " + root.formatarDuracao(modelData.duration_hours) + " nesse ritmo — chega no reset"
                            color: modelData.limited_by === "cap" ? Theme.error : "#7fb069"
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        StyledText {
                            width: parent.width
                            visible: !!modelData.resets_in
                            text: "reinicia em " + modelData.resets_in
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
                visible: !root.failed
            }

            StyledText {
                width: parent.width
                visible: !root.failed && root.stats.api_equivalent_cost_usd !== undefined
                text: root.formatarUsd(root.stats.api_equivalent_cost_usd) + " via API  ·  plano " + root.formatarUsd(root.stats.plan_price_usd) + "/mês"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
