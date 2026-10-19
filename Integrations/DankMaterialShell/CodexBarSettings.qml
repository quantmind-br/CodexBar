import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "codexBar"

    StyledText {
        width: parent.width
        text: "CodexBar"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "The bar reads the codexbar-linux backend snapshot; it never queries providers itself. Providers, accounts, polling, notifications and bar detail live in the CodexBar Settings window."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "desktopExecutable"
        label: "Backend executable"
        description: "CodexBar Linux desktop app that owns polling"
        placeholder: "codexbar-linux"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "startBackend"
        label: "Start backend"
        description: "Launch the backend in the background when the bar finds it absent"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "iconsOnly"
        label: "Icons only"
        description: "Show only the configured providers' marks in the bar; a mark turns to the warning color when its quota runs low"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "pollSeconds"
        label: "Snapshot interval"
        description: "How often the bar reads the backend's cached snapshot"
        defaultValue: 5
        minimum: 2
        maximum: 60
        unit: "s"
        leftIcon: "schedule"
    }

    DankButton {
        text: "Open CodexBar Settings"
        iconName: "settings"
        onClicked: Quickshell.execDetached([String(root.loadValue("desktopExecutable", "") || "codexbar-linux"), "--settings"])
    }
}
