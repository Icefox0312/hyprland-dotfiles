import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    readonly property FileView _walFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var rawData: {
        try { return JSON.parse(_walFile.text()) } 
        catch (e) { return null }
    }

    readonly property color background: rawData?.special?.background ?? "#1e1e2e"
    readonly property color foreground: rawData?.special?.foreground ?? "#cdd6f4"
    
    readonly property color color0: rawData?.colors?.color0 ?? "#45475a"
    readonly property color color4: rawData?.colors?.color4 ?? "#89b4fa"

    readonly property color cardBg: Qt.rgba(background.r, background.g, background.b, 0.85)
    readonly property color surface: Qt.rgba(color0.r, color0.g, color0.b, 0.5)
    readonly property color primary: color4
    readonly property color border: Qt.rgba(color4.r, color4.g, color4.b, 0.35)
}