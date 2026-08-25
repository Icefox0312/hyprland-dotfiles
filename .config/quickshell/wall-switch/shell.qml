import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    Theme { id: theme }

    PanelWindow {
        id: window
        visible: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-wall-switch"
        
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

        property var allWallpapers: []

        FolderListModel {
            id: folderModel
            folder: "file://" + Quickshell.env("HOME") + "/Pictures/Wallpapers"
            nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.mp4]
            showDirs: false
            onCountChanged: {
                let temp = [];
                for (let i = 0; i < count; i++) {
                    temp.push({
                        filePath: get(i, "filePath")
                    });
                }
                window.allWallpapers = temp;
            }
        }

        Rectangle {
            // Increased window size to fit 3 columns of larger wallpapers
            width: 1020
            height: 680
            anchors.centerIn: parent
            radius: 16
            color: theme.cardBg
            border.color: theme.border
            border.width: 1

            MouseArea { anchors.fill: parent; preventStealing: true }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 25

                GridView {
                    id: wallpaperGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    // Grab keyboard focus since the search bar is gone
                    focus: true 
                    
                    // Increased grid cell sizes
                    cellWidth: 320
                    cellHeight: 200

                    model: window.allWallpapers

                    // Apply the wallpaper when Enter is pressed
                    Keys.onReturnPressed: (event) => {
                        if (wallpaperGrid.currentItem) {
                            wallpaperGrid.currentItem.applyWall();
                        }
                        event.accepted = true;
                    }

                    delegate: Rectangle {
                        id: delegateItem
                        required property var modelData
                        required property int index

                        // Increased image sizes
                        width: 300
                        height: 180
                        radius: 12
                        
                        property bool isSelected: GridView.isCurrentItem || wallMouse.containsMouse
                        
                        color: theme.surface
                        border.color: isSelected ? theme.primary : "transparent"
                        border.width: 3 // Thicker border to make the selection pop
                        clip: true

                        function applyWall() {
                            const cleanPath = modelData.filePath.replace("file://", "");
                            Quickshell.execDetached([
                                Quickshell.env("HOME") + "/.local/bin/apply_wallpaper.sh",
                                cleanPath
                            ]);
                            Qt.quit();
                        }

                        Image {
                            anchors.fill: parent
                            source: delegateItem.modelData.filePath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            // Darken non-selected images slightly for better contrast
                            opacity: delegateItem.isSelected ? 1.0 : 0.6
                        }

                        MouseArea {
                            id: wallMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: delegateItem.applyWall()
                            onEntered: wallpaperGrid.currentIndex = index
                        }
                    }
                }
            }
        }
    }
}