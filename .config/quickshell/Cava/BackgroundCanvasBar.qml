import QtQuick
import QtQuick.Layouts
import QtQml
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    anchors {
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Let clicks pass through completely
    mask: Region {}

    // Take up half screen height
    implicitHeight: screen ? screen.height * 0.5 : 540
    color: "transparent"

    // --- Dynamic Wallpaper Colors ---
    property color colorAccent1: "#ff007f"
    property color colorAccent2: "#7928ca"
    property color colorAccent3: "#00dfd8"

    Process {
        id: colorReader
        command: ["cat", Quickshell.env("HOME") + "/.cache/wal/colors.json"]
        property string buffer: ""
        
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                colorReader.buffer += data;
            }
        }

        onExited: {
            try {
                var parsed = JSON.parse(buffer);
                if (parsed && parsed.colors) {
                    root.colorAccent1 = parsed.colors.color1 || root.colorAccent1;
                    root.colorAccent2 = parsed.colors.color4 || root.colorAccent2;
                    root.colorAccent3 = parsed.colors.color6 || root.colorAccent3;
                }
            } catch(e) {
                console.log("Failed to parse pywal colors:", e)
            }
            buffer = ""; 
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!colorReader.running) colorReader.running = true;
        }
    }

    // --- MPRIS Media Playback State ---
    property bool isPlaying: false

    // A lightweight, highly robust timer to constantly check playback state 
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            var playing = false;
            
            // Correctly iterating over the dictionary using a for...in loop
            for (var key in Mpris.players.values) {
                var p = Mpris.players.values[key];
                if (p && p.playbackState === MprisPlaybackState.Playing) {
                    playing = true;
                    break;
                }
            }
            
            root.isPlaying = playing;
        }
    }

    // Controls visibility and 5-second lingering delay
    property bool shouldShow: false

    Timer {
        id: hideTimer
        interval: 5000 // 5 seconds
        repeat: false
        onTriggered: {
            root.shouldShow = false;
        }
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            hideTimer.stop();
            shouldShow = true;
        } else {
            hideTimer.restart();
        }
    }

    // Raw FFT Audio Buffer
    property var rawFft: []

    // Cava stays alive while the visualizer is showing
    Process {
        id: cavaProcess
        // Ensure this path matches the Cava/ folder where your config lives
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/Cava/cava.conf"]
        running: root.shouldShow
        
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var clean = data.trim();
                if (clean.length > 0) {
                    var parts = clean.split(";").filter(x => x !== "");
                    root.rawFft = parts.map(v => parseInt(v) || 0);
                }
            }
        }
    }

    // --- High-Performance GPU Visualizer Grid ---
    Row {
        id: visualizerRow
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // Smooth fade out and slide down after the 5s timer expires
        opacity: root.shouldShow ? 1.0 : 0.0
        y: root.shouldShow ? 0 : 50

        Behavior on opacity {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }

        readonly property int barCount: root.rawFft.length > 0 ? root.rawFft.length : 60
        readonly property real calculatedBarWidth: Math.max(12, (width - (spacing * (barCount - 1))) / barCount)

        Repeater {
            model: visualizerRow.barCount

            Item {
                id: barContainer
                width: visualizerRow.calculatedBarWidth
                height: parent.height

                // Bulletproof array reactivity check
                readonly property int rawValue: {
                    var currentFft = root.rawFft; 
                    if (root.isPlaying && currentFft.length > index && currentFft[index] !== undefined) {
                        return currentFft[index];
                    }
                    return 0;
                }
                
                readonly property real targetHeight: root.isPlaying 
                    ? Math.max(8, (rawValue / 100.0) * (parent.height - 10))
                    : (root.shouldShow ? 8 : 0)

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: barContainer.targetHeight
                    radius: width / 2

                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: root.colorAccent3 }
                        GradientStop { position: 0.5; color: root.colorAccent2 }
                        GradientStop { position: 1.0; color: root.colorAccent1 }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: root.isPlaying ? 50 : 400
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }
}