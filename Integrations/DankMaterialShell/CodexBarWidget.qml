import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

// Presentation only. The codexbar-linux backend owns settings, polling and notifications.
PluginComponent {
    id: root

    property var snapshot: ({})
    property bool available: false
    property string response: ""
    property double lastLaunch: 0

    readonly property string executable: String(pluginData.desktopExecutable || "codexbar-linux")
    readonly property bool startBackend: pluginData.startBackend !== false
    readonly property int pollSeconds: Math.max(2, Number(pluginData.pollSeconds || 5))
    readonly property bool iconsOnly: pluginData.iconsOnly !== false
    // One segment per displayed provider; older backends publish no barEntries and get the plain label.
    // Marks alone take little room, so icons-only mode shows every configured provider.
    readonly property var segments: {
        if (!available || !Array.isArray(snapshot.barEntries))
            return [];
        if (iconsOnly && Array.isArray(snapshot.entries))
            return snapshot.entries.map(entry => ({
                        "provider": entry.provider,
                        "tag": entry.provider,
                        "text": ""
                    }));
        return snapshot.barEntries;
    }
    readonly property int extra: {
        const total = available && Array.isArray(snapshot.entries) ? snapshot.entries.length : 0;
        return total - segments.length;
    }
    readonly property bool warning: {
        if (!available || !Array.isArray(snapshot.entries))
            return false;
        return snapshot.entries.some(entry => (entry.windows || []).some(window => window.warning === true));
    }
    readonly property color pillColor: !available ? Theme.surfaceVariantText : warning ? Theme.tempWarning : Theme.surfaceText
    readonly property real textSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)

    function poll() {
        if (!reader.running)
            reader.running = true;
    }

    function launch(page) {
        Quickshell.execDetached([executable, "--" + page]);
        closePopout();
    }

    function refresh() {
        Quickshell.execDetached([executable, "--refresh"]);
        Qt.callLater(poll);
    }

    // The backend may not be autostarted under every compositor; start it once a minute at most.
    function ensureBackend() {
        if (!startBackend || Date.now() - lastLaunch < 60000)
            return;
        lastLaunch = Date.now();
        Quickshell.execDetached([executable, "--background"]);
    }

    // With the quota text hidden, each mark carries its own provider's low-quota warning.
    function markColor(provider) {
        const entry = (snapshot.entries || []).find(item => item.provider === provider);
        const low = !!entry && (entry.windows || []).some(window => window.warning === true);
        return low ? Theme.tempWarning : Theme.surfaceText;
    }

    // Providers that share another provider's mark, matching their descriptors' iconResourceName.
    function iconName(id) {
        const shared = {
            "alibabatokenplan": "alibaba",
            "azureopenai": "codex",
            "moonshot": "kimi",
            "openai": "codex"
        };
        return shared[id] || id;
    }

    function providerName(id) {
        const names = {
            "codex": "Codex",
            "claude": "Claude",
            "copilot": "GitHub Copilot",
            "gemini": "Gemini",
            "cursor": "Cursor",
            "antigravity": "Antigravity",
            "openrouter": "OpenRouter",
            "kiro": "Kiro"
        };
        return names[id] || (id ? id.charAt(0).toUpperCase() + id.slice(1) : "Unknown provider");
    }

    function quotaValue(window) {
        return window.displayValue === undefined ? window.remaining : window.displayValue;
    }

    function money(value) {
        return typeof value === "number" && isFinite(value) ? "$" + value.toFixed(2) : "—";
    }

    pillRightClickAction: () => root.refresh()

    Component.onCompleted: Qt.callLater(poll)

    Timer {
        interval: root.pollSeconds * 1000
        running: true
        repeat: true
        onTriggered: root.poll()
    }

    Process {
        id: reader
        command: [root.executable, "--snapshot"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.response = text
        }
        stderr: StdioCollector {}
        onExited: function (code) {
            try {
                const data = JSON.parse(root.response);
                if (code !== 0 || data.schemaVersion !== 1 || !Array.isArray(data.entries))
                    throw new Error("Unavailable");
                root.snapshot = data;
                root.available = true;
            } catch (error) {
                root.available = false;
                root.ensureBackend();
            }
        }
    }

    component ProviderMark: Item {
        id: mark
        property string provider: ""
        property string tag: ""
        property color tint: Theme.surfaceText
        readonly property bool loaded: logo.status === Image.Ready

        implicitWidth: loaded ? logo.width : fallback.implicitWidth
        implicitHeight: loaded ? logo.height : fallback.implicitHeight

        Image {
            id: logo
            anchors.centerIn: parent
            // A provider without an installed logo keeps its text tag instead of a gap.
            source: mark.provider ? Qt.resolvedUrl("icons/ProviderIcon-" + root.iconName(mark.provider) + ".svg") : ""
            sourceSize: Qt.size(root.iconSize, root.iconSize)
            visible: false
        }

        MultiEffect {
            anchors.fill: logo
            source: logo
            visible: mark.loaded
            // Flatten every pixel to white first, so black logos also become an exact tint.
            contrast: -1.0
            brightness: 0.5
            colorization: 1.0
            colorizationColor: mark.tint
        }

        StyledText {
            id: fallback
            anchors.centerIn: parent
            visible: !mark.loaded
            text: mark.tag || mark.provider
            color: mark.tint
            font.pixelSize: root.textSize
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                visible: !root.available || root.segments.length === 0
                name: "data_usage"
                size: root.iconSize
                color: root.pillColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: !root.available || root.segments.length === 0
                text: !root.available ? "—" : (root.snapshot.summary || "—")
                color: root.pillColor
                font.pixelSize: root.textSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.available && root.snapshot.stale === true
                text: "!"
                color: Theme.tempWarning
                font.pixelSize: root.textSize
                anchors.verticalCenter: parent.verticalCenter
            }

            Repeater {
                model: root.segments

                Row {
                    required property var modelData
                    required property int index
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        visible: index > 0 && !root.iconsOnly
                        text: "│"
                        color: Theme.outline
                        font.pixelSize: root.textSize
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ProviderMark {
                        provider: modelData.provider || ""
                        tag: modelData.tag || ""
                        tint: root.markColor(modelData.provider)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        visible: !root.iconsOnly
                        text: modelData.text || ""
                        color: Theme.surfaceText
                        font.pixelSize: root.textSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            StyledText {
                visible: root.extra > 0 && root.segments.length > 0
                text: "+" + root.extra
                color: Theme.surfaceVariantText
                font.pixelSize: root.textSize
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                visible: !root.available || root.segments.length === 0
                name: "data_usage"
                size: root.iconSize
                color: root.pillColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Repeater {
                model: root.segments

                Column {
                    required property var modelData
                    spacing: 1
                    anchors.horizontalCenter: parent.horizontalCenter

                    ProviderMark {
                        provider: modelData.provider || ""
                        tag: modelData.tag || ""
                        tint: root.markColor(modelData.provider)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        visible: !root.iconsOnly
                        // The vertical bar has room for the leading lane only.
                        text: String(modelData.text || "").split(" · ")[0]
                        color: Theme.surfaceText
                        font.pixelSize: root.textSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "CodexBar"
            detailsText: {
                if (!root.available)
                    return "Backend not running";
                if (root.snapshot.error)
                    return root.snapshot.error;
                if (root.snapshot.busy)
                    return "Refreshing…";
                return "Updated " + root.snapshot.updated + (root.snapshot.stale ? " · older data" : "");
            }
            showCloseButton: true

            headerActions: Component {
                DankActionButton {
                    iconName: root.snapshot.busy ? "hourglass_empty" : "refresh"
                    iconColor: Theme.surfaceText
                    buttonSize: Theme.iconSize + Theme.spacingS
                    enabled: root.available
                    onClicked: root.refresh()
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    width: parent.width
                    visible: !root.available
                    text: root.startBackend ? "Starting the CodexBar backend… Check that " + root.executable + " is installed." : "Start " + root.executable + " --background to see usage."
                    wrapMode: Text.WordWrap
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }

                Repeater {
                    model: root.available ? root.snapshot.entries : []

                    Column {
                        id: provider
                        required property var modelData
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            spacing: Theme.spacingS

                            ProviderMark {
                                provider: provider.modelData.provider
                                tint: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: root.providerName(provider.modelData.provider)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                visible: !!provider.modelData.plan
                                text: provider.modelData.plan
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: provider.modelData.error || ""
                            wrapMode: Text.WordWrap
                            color: Theme.tempWarning
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        StyledText {
                            width: parent.width
                            visible: text !== "" && provider.modelData.statusLevel !== "none"
                            text: provider.modelData.status || ""
                            wrapMode: Text.WordWrap
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Repeater {
                            model: provider.modelData.windows || []

                            Column {
                                id: lane
                                required property var modelData
                                readonly property real value: root.quotaValue(modelData)
                                width: parent.width
                                spacing: Theme.spacingXS

                                Row {
                                    width: parent.width

                                    StyledText {
                                        width: parent.width / 2
                                        text: lane.modelData.label
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        width: parent.width / 2
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(lane.value) + "% " + (lane.modelData.displaySuffix || "left")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: lane.modelData.warning ? Theme.tempWarning : Theme.surfaceText
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 8

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: Theme.surfaceContainerHighest
                                    }

                                    Rectangle {
                                        width: Math.max(height, parent.width * Math.max(0, Math.min(1, lane.value / 100)))
                                        height: parent.height
                                        radius: height / 2
                                        color: lane.modelData.warning ? Theme.tempWarning : Theme.primary
                                    }
                                }

                                StyledText {
                                    visible: text !== ""
                                    text: lane.modelData.resetText || ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS
                    visible: root.available && Array.isArray(root.snapshot.spending) && root.snapshot.spending.length > 0

                    StyledText {
                        text: "Local spending"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                    }

                    Repeater {
                        model: root.available && Array.isArray(root.snapshot.spending) ? root.snapshot.spending : []

                        StyledText {
                            required property var modelData
                            width: parent.width
                            text: root.providerName(modelData.provider) + " · today " + root.money(modelData.today) + " · 30 days " + root.money(modelData.month)
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }
                }

                Row {
                    spacing: Theme.spacingS

                    DankButton {
                        text: "Usage & Spend"
                        iconName: "bar_chart"
                        onClicked: root.launch("usage")
                    }

                    DankButton {
                        text: "Settings"
                        iconName: "settings"
                        onClicked: root.launch("settings")
                    }
                }
            }
        }
    }

    popoutWidth: 380
    popoutHeight: 0
}
