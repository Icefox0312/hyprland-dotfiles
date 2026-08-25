import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    Theme { id: theme }

    PanelWindow {
        id: window
        visible: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-app-launcher"
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        color: "transparent"

        Shortcut {
            sequence: "Escape"
            onActivated: Qt.quit()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        property var allApps: DesktopEntries.applications.values
        property var filteredApps: {
            if (searchInput.text.length === 0) return allApps;
            let q = searchInput.text.toLowerCase();
            return allApps.filter(app => 
                (app.name && app.name.toLowerCase().includes(q)) ||
                (app.genericName && app.genericName.toLowerCase().includes(q))
            );
        }

        Rectangle {
            width: 600
            height: 500
            anchors.centerIn: parent
            radius: 16
            color: theme.cardBg
            border.color: theme.border
            border.width: 1

            MouseArea { anchors.fill: parent; preventStealing: true }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 8
                    color: theme.surface
                    border.color: searchInput.activeFocus ? theme.primary : "transparent"
                    border.width: 1

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: theme.foreground
                        font.pixelSize: 14
                        focus: true
                        
                        Text {
                            text: "Search applications..."
                            color: Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.4)
                            font.pixelSize: 14
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: appList.currentIndex = 0

                        // FIX: Explicit (event) parameters added here
                        Keys.onDownPressed: (event) => {
                            appList.incrementCurrentIndex();
                            event.accepted = true;
                        }
                        Keys.onUpPressed: (event) => {
                            appList.decrementCurrentIndex();
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: (event) => {
                            if (appList.currentItem) {
                                appList.currentItem.launch();
                            }
                            event.accepted = true;
                        }
                    }
                }

                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    
                    model: window.filteredApps

                    delegate: Rectangle {
                        id: delegateItem
                        required property var modelData
                        required property int index

                        width: appList.width
                        height: 48
                        radius: 8
                        
                        property bool isSelected: ListView.isCurrentItem || appMouse.containsMouse
                        color: isSelected ? theme.surface : "transparent"

                        function launch() {
                            // If modelData.execute() throws an error in the future, 
                            // you can also try modelData.launch() instead.
                            modelData.execute();
                            Qt.quit();
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12

                            Image {
                                id: appIcon
                                property string iconName: delegateItem.modelData.icon || "application-x-executable"
                                
                                source: iconName.startsWith("/") ? "file://" + iconName : "image://icon/" + iconName
                                
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                sourceSize: Qt.size(28, 28)
                                fillMode: Image.PreserveAspectFit
                                
                                // Fallback logic: if the system icon theme doesn't have it, use a generic executable icon
                                onStatusChanged: {
                                    if (status === Image.Error && String(source) !== "image://icon/application-x-executable") {
                                        source = "image://icon/application-x-executable"
                                    }
                                }
                            }

                            Text {
                                text: delegateItem.modelData.name
                                color: theme.foreground
                                font.pixelSize: 14
                                font.bold: true
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: delegateItem.launch()
                            onEntered: appList.currentIndex = index
                        }
                    }
                }
            }
        }
    }
}