import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris

PanelWindow {
    id: pywalBar
    
    anchors { top: true; left: true; right: true }
    
    implicitHeight: 430
    exclusiveZone: 50 
    color: "transparent"

    // ==========================================
    // WAYLAND FOCUS & MASK ENGINE
    // ==========================================
    focusable: activeState !== "clock"

    mask: Region {
        item: island
    }

    // ==========================================
    // NATIVE SYSTEM EXECUTION ENGINE
    // ==========================================
    Process { id: sysCmd }
    function runSys(cmd) { sysCmd.exec(["bash", "-c", cmd]); }

    // Safely quote text before passing it to bash.
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    Process { id: briCmd }
    Timer { id: briDebouncer; interval: 20; property int target: 0; onTriggered: briCmd.exec(["bash", "-c", "brightnessctl set " + target + "%"]) }

    Process { id: volCmd }
    Timer { id: volDebouncer; interval: 20; property int target: 0; onTriggered: volCmd.exec(["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + target + "%"]) }

    // ==========================================
    // DYNAMIC LIST MODELS & SCANNERS
    // ==========================================
    ListModel { id: wifiModel }
    ListModel { id: pairedBtModel }
    ListModel { id: scannedBtModel }
    property string selectedSsid: ""

    Process {
        id: wifiConnector
        property string targetSsid: ""
        onExited: {
            if (exitCode !== 0) {
                selectedSsid = wifiConnector.targetSsid;
                passwordInput.text = "";
                activeState = "cc_wifi_pass";
            } else {
                activeState = "clock";
            }
        }
    }

    // Smart Wi-Fi Scanner
    Process {
        id: wifiScanner
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                var lines = text.split('\n');
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split('|');
                    if (parts.length >= 3 && parts[0].trim() !== "") {
                        var ssid = parts[0].trim();
                        var active = parts[1].trim() === "yes";
                        var signal = parts[2].trim();
                        if (ssid !== "" && ssid !== "--") {
                            var foundIndex = -1;
                            for (var j = 0; j < wifiModel.count; j++) {
                                if (wifiModel.get(j).ssid === ssid) {
                                    foundIndex = j;
                                    break;
                                }
                            }
                            if (foundIndex !== -1) {
                                wifiModel.setProperty(foundIndex, "active", active);
                                wifiModel.setProperty(foundIndex, "signal", signal);
                            } else {
                                if (wifiModel.count === 1 && (wifiModel.get(0).ssid === "No networks found" || wifiModel.get(0).ssid === "Scanning networks...")) {
                                    wifiModel.clear();
                                }
                                wifiModel.append({ssid: ssid, active: active, signal: signal});
                            }
                        }
                    }
                }
                if (wifiModel.count === 0) {
                    wifiModel.clear();
                    wifiModel.append({ssid: "No networks found", active: false, signal: ""});
                }
            }
        }
    }

    // Dual-List Bluetooth Scanner
    Process {
        id: btScanner
        stdout: StdioCollector {
            onStreamFinished: {
                if (text) {
                    var lines = text.split('\n');
                    var section = "";
                    var pairedMacs = {};
                    var newPaired = [];
                    var newScanned = [];

                    for (var i = 0; i < lines.length; i++) {
                        var cleanLine = lines[i].replace(/\x1b\[[0-9;]*m/g, '').trim();
                        if (cleanLine === "---PAIRED---") {
                            section = "paired";
                            continue;
                        } else if (cleanLine === "---DEVICES---") {
                            section = "devices";
                            continue;
                        }

                        var match = cleanLine.match(/Device\s+(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2})\s+(.*)/);
                        if (match) {
                            var mac = match[1];
                            var name = match[3];
                            if (section === "paired") {
                                pairedMacs[mac] = true;
                                if (!hasItem(pairedBtModel, mac)) {
                                    newPaired.push({mac: mac, name: name});
                                }
                            } else if (section === "devices") {
                                if (!pairedMacs[mac] && !hasItem(scannedBtModel, mac) && !hasItem(pairedBtModel, mac)) {
                                    newScanned.push({mac: mac, name: name});
                                }
                            }
                        }
                    }

                    // Handle Paired Devices
                    if (newPaired.length > 0) {
                        if (pairedBtModel.count === 1 && pairedBtModel.get(0).mac === "") {
                            pairedBtModel.clear();
                        }
                        for (var p = 0; p < newPaired.length; p++) {
                            if (!hasItem(pairedBtModel, newPaired[p].mac)) {
                                pairedBtModel.append(newPaired[p]);
                            }
                        }
                    }

                    // Handle Scanned Devices
                    if (newScanned.length > 0) {
                        if (scannedBtModel.count === 1 && scannedBtModel.get(0).mac === "") {
                            scannedBtModel.clear();
                        }
                        for (var s = 0; s < newScanned.length; s++) {
                            if (!hasItem(scannedBtModel, newScanned[s].mac)) {
                                scannedBtModel.append(newScanned[s]);
                            }
                        }
                    }
                }

                // Fallbacks if empty after checking
                if (pairedBtModel.count === 1 && pairedBtModel.get(0).mac === "") {
                    pairedBtModel.clear();
                    pairedBtModel.append({mac: "", name: "No paired devices"});
                }

                if (scannedBtModel.count === 1 && scannedBtModel.get(0).mac === "") {
                    scannedBtModel.clear();
                    scannedBtModel.append({mac: "", name: "No available devices"});
                }
            }
        }
    }

    function hasItem(model, mac) {
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).mac === mac) return true;
        }
        return false;
    }

    // ==========================================
    // LIVE REFRESH TIMER
    // ==========================================
    Timer {
        id: liveScanTimer
        interval: 3000
        running: activeState === "cc_wifi" || activeState === "cc_bt"
        repeat: true
        onTriggered: {
            if (activeState === "cc_wifi") {
                wifiScanner.exec(["bash", "-c", "nmcli -t --escape no -f SSID,ACTIVE,SIGNAL device wifi list | awk -F: '{print $1 \"|\" $2 \"|\" $3}'"]);
            } else if (activeState === "cc_bt") {
                btScanner.exec(["bash", "-c", "echo '---PAIRED---'; bluetoothctl devices Paired; echo '---DEVICES---'; bluetoothctl --timeout 2 scan on"]);
            }
        }
    }

    // ==========================================
    // PYWAL COLOR ENGINE
    // ==========================================
    property var pywalColors: ({ background: "#1e1e1e", foreground: "#d4d4d4", primary: "#888888", accent: "#555555" })

    Process {
        id: pywalReader
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                try {
                    var data = JSON.parse(text);
                    pywalColors = { background: data.special.background, foreground: data.special.foreground, primary: data.colors.color4, accent: data.colors.color2 };
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: pywalReader.exec(["bash", "-c", "cat ~/.cache/wal/colors.json"])
    Timer { interval: 3000; running: true; repeat: true; onTriggered: pywalReader.exec(["bash", "-c", "cat ~/.cache/wal/colors.json"]) }

    // --- CLOCK & STATE ---
    property string activeWsName: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : "1"
    property bool showingWsText: false
    property string clockStr: Qt.formatDateTime(new Date(), "h:mm AP") 
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clockStr = Qt.formatDateTime(new Date(), "h:mm AP") }
    onActiveWsNameChanged: { showingWsText = true; wsTimer.restart(); }
    Timer { id: wsTimer; interval: 2000; onTriggered: showingWsText = false }

    property string activeState: "clock" 

    onActiveStateChanged: {
        if (activeState === "cc_wifi") {
            wifiModel.clear();
            wifiModel.append({ssid: "Scanning networks...", active: false, signal: ""});
            runSys("nmcli device wifi rescan");
            wifiScanner.exec(["bash", "-c", "nmcli -t --escape no -f SSID,ACTIVE,SIGNAL device wifi list | awk -F: '{print $1 \"|\" $2 \"|\" $3}'"]);
        } else if (activeState === "cc_bt") {
            pairedBtModel.clear();
            scannedBtModel.clear();
            pairedBtModel.append({mac: "", name: "Loading paired devices..."});
            scannedBtModel.append({mac: "", name: "Scanning for devices..."});
            btScanner.exec(["bash", "-c", "echo '---PAIRED---'; bluetoothctl devices Paired; echo '---DEVICES---'; bluetoothctl --timeout 2 scan on"]);
        }
    }

    // ==========================================
    // THE DYNAMIC ISLAND UI
    // ==========================================
    Rectangle {
        id: island
        anchors.top: parent.top; anchors.topMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
        color: pywalColors.background
        border.color: activeState === "clock" ? "transparent" : pywalColors.primary
        border.width: activeState === "clock" ? 0 : 2
        clip: true

        Timer {
        id: closeTimer
        interval: 0500
        onTriggered: activeState = "clock"
    }

    Connections {
        target: pywalBar
        function onActiveStateChanged() {
            if (activeState !== "clock") {
                island.forceActiveFocus();
            }
        }
    }

    focus: activeState !== "clock"
    Keys.onEscapePressed: {
        closeTimer.stop();
        activeState = "clock";
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onExited: {
            if (activeState !== "clock") {
                closeTimer.restart();
            }
        }
        onEntered: {
            closeTimer.stop();
        }
    }

        width: { 
            if (activeState === "cc" || activeState === "cc_wifi" || activeState === "cc_bt" || activeState === "cc_wifi_pass") return 340; 
            if (activeState === "media") return 300; 
            return clockContent.implicitWidth + 40; 
        }
        height: { 
            if (activeState === "cc_wifi_pass") return 230;
            if (activeState === "cc_wifi" || activeState === "cc_bt") return 410; 
            if (activeState === "cc") return 230; 
            if (activeState === "media") return 170; 
            return 32; 
        }
        radius: activeState === "clock" ? 16 : 20

        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
        Behavior on radius { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }

        // ------------------------------------------
        // A: THE CLOCK 
        // ------------------------------------------
        Row {
            id: clockContent
            anchors.centerIn: parent; spacing: 8
            opacity: activeState === "clock" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text { text: showingWsText ? "󰰓" : ""; color: pywalColors.accent; font.bold: true; font.pixelSize: 16 }
            Text { text: showingWsText ? ("Workspace " + activeWsName) : clockStr; color: pywalColors.foreground; font.bold: true; font.pixelSize: 16 }
        }

        MouseArea {
            anchors.fill: parent; enabled: activeState === "clock"; acceptedButtons: Qt.LeftButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) activeState = "cc";
                else if (mouse.button === Qt.RightButton) activeState = "media";
            }
        }

        // ------------------------------------------
        // B: CONTROL CENTER (Main View)
        // ------------------------------------------
        Column {
            id: ccContent
            anchors.fill: parent; anchors.margins: 20; spacing: 20
            opacity: activeState === "cc" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            property bool wifiOn: true
            property bool btOn: true
            property int currentVolume: 50
            property int currentBrightness: 70

            Rectangle {
                width: 300; height: 24; color: "transparent"
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: ""; color: pywalColors.accent; font.bold: true; font.pixelSize: 16 }
                    Text { text: "Control Center"; color: pywalColors.foreground; font.bold: true; font.pixelSize: 16 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeState = "clock" }
            }

            Row {
                spacing: 15; anchors.horizontalCenter: parent.horizontalCenter
                
                // Wi-Fi Tile
                Rectangle {
                    width: 140; height: 50; radius: 10
                    color: ccContent.wifiOn ? pywalColors.accent : pywalColors.primary
                    Row {
                        anchors.fill: parent
                        Item {
                            width: 100; height: parent.height
                            Column {
                                anchors.centerIn: parent; spacing: 2
                                Text { text: ""; color: pywalColors.background; font.bold: true; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: ccContent.wifiOn ? "Wi-Fi On" : "Wi-Fi Off"; color: pywalColors.background; font.pixelSize: 11; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ccContent.wifiOn = !ccContent.wifiOn; runSys("nmcli radio wifi " + (ccContent.wifiOn ? "on" : "off")); } }
                        }
                        Rectangle { width: 1; height: 30; color: pywalColors.background; opacity: 0.3; anchors.verticalCenter: parent.verticalCenter }
                        Item {
                            width: 39; height: parent.height
                            Text { text: ""; color: pywalColors.background; font.pixelSize: 12; anchors.centerIn: parent }
                            MouseArea { 
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                                onClicked: { activeState = "cc_wifi"; } 
                            }
                        }
                    }
                }
                
                // Bluetooth Tile
                Rectangle {
                    width: 140; height: 50; radius: 10
                    color: ccContent.btOn ? pywalColors.accent : pywalColors.primary
                    Row {
                        anchors.fill: parent
                        Item {
                            width: 100; height: parent.height
                            Column {
                                anchors.centerIn: parent; spacing: 2
                                Text { text: ""; color: pywalColors.background; font.bold: true; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: ccContent.btOn ? "Bluetooth On" : "Bluetooth Off"; color: pywalColors.background; font.pixelSize: 11; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ccContent.btOn = !ccContent.btOn; runSys("rfkill " + (ccContent.btOn ? "unblock" : "block") + " bluetooth"); } }
                        }
                        Rectangle { width: 1; height: 30; color: pywalColors.background; opacity: 0.3; anchors.verticalCenter: parent.verticalCenter }
                        Item {
                            width: 39; height: parent.height
                            Text { text: ""; color: pywalColors.background; font.pixelSize: 12; anchors.centerIn: parent }
                            MouseArea { 
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                                onClicked: { activeState = "cc_bt"; } 
                            }
                        }
                    }
                }
            }

            // Brightness Slider
            Row {
                spacing: 15; anchors.horizontalCenter: parent.horizontalCenter
                Text { text: ""; color: pywalColors.foreground; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter; width: 20 }
                Rectangle {
                    width: 200; height: 12; radius: 6; color: pywalColors.primary; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: parent.width * (ccContent.currentBrightness / 100); height: 12; radius: 6; color: pywalColors.accent; Behavior on width { NumberAnimation { duration: 50 } } }
                    MouseArea { 
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                        function updateBri(mouse) { 
                            var w = width > 0 ? width : 200;
                            var p = Math.max(0, Math.min(100, Math.round((mouse.x/w)*100))); 
                            ccContent.currentBrightness = p; 
                            briDebouncer.target = p; 
                            briDebouncer.restart(); 
                        } 
                        onClicked: (mouse) => updateBri(mouse); 
                        onPositionChanged: (mouse) => { if (pressed) updateBri(mouse) } 
                    }
                }
                Text { text: ccContent.currentBrightness + "%"; color: pywalColors.foreground; width: 35; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }

            // Volume Slider
            Row {
                spacing: 15; anchors.horizontalCenter: parent.horizontalCenter
                Text { text: ""; color: pywalColors.foreground; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter; width: 20 }
                Rectangle {
                    width: 200; height: 12; radius: 6; color: pywalColors.primary; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: parent.width * (ccContent.currentVolume / 100); height: 12; radius: 6; color: pywalColors.accent; Behavior on width { NumberAnimation { duration: 50 } } }
                    MouseArea { 
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; 
                        function updateVol(mouse) { 
                            var w = width > 0 ? width : 200;
                            var p = Math.max(0, Math.min(100, Math.round((mouse.x/w)*100))); 
                            ccContent.currentVolume = p; 
                            volDebouncer.target = p; 
                            volDebouncer.restart(); 
                        } 
                        onClicked: (mouse) => updateVol(mouse); 
                        onPositionChanged: (mouse) => { if (pressed) updateVol(mouse) } 
                    }
                }
                Text { text: ccContent.currentVolume + "%"; color: pywalColors.foreground; width: 35; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // ------------------------------------------
        // C: WI-FI LIST SUBMENU
        // ------------------------------------------
        Column {
            anchors.fill: parent; anchors.margins: 20; spacing: 15
            opacity: activeState === "cc_wifi" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                width: 300; height: 24; color: "transparent"
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: ""; color: pywalColors.primary; font.bold: true; font.pixelSize: 16 }
                    Text { text: "Wi-Fi Networks"; color: pywalColors.foreground; font.bold: true; font.pixelSize: 16 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeState = "cc" }
            }

            ListView {
                width: 300; height: 320; clip: true; spacing: 8; model: wifiModel
                delegate: Rectangle {
                    width: 300; height: 40; radius: 8
                    color: model.active ? pywalColors.accent : "transparent"
                    border.color: model.active ? "transparent" : pywalColors.primary; border.width: 1
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 15; anchors.right: parent.right; anchors.rightMargin: 15
                        spacing: 15
                        Text { text: ""; color: model.active ? pywalColors.background : pywalColors.foreground }
                        Text { text: model.ssid; color: model.active ? pywalColors.background : pywalColors.foreground; width: 170; elide: Text.ElideRight; font.bold: model.active }
                        Item { width: 10; height: 1 }
                        Text { text: model.signal !== "" ? (model.signal + "%") : ""; color: model.active ? pywalColors.background : pywalColors.primary; font.pixelSize: 12 }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (model.active) {
                                activeState = "clock";
                            } else {
                                wifiConnector.targetSsid = model.ssid;
                                wifiConnector.exec(["bash", "-c", "nmcli dev wifi connect " + shellQuote(model.ssid)]);
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------
        // F: WI-FI PASSWORD SUBMENU (Inline Typing)
        // ------------------------------------------
        Column {
            anchors.fill: parent; anchors.margins: 20; spacing: 15
            opacity: activeState === "cc_wifi_pass" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                width: 300; height: 24; color: "transparent"
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: ""; color: pywalColors.primary; font.bold: true; font.pixelSize: 16 }
                    Text { text: "Enter Password"; color: pywalColors.foreground; font.bold: true; font.pixelSize: 16 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeState = "cc_wifi" }
            }

            Text { 
                text: "Network: " + selectedSsid
                color: pywalColors.foreground
                font.pixelSize: 13
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
                width: 280; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
            }

            Rectangle {
                width: 280; height: 42; radius: 8
                color: "transparent"
                border.color: pywalColors.primary; border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter

                TextInput {
                    id: passwordInput
                    anchors.fill: parent; anchors.margins: 12
                    color: pywalColors.foreground
                    font.pixelSize: 14
                    echoMode: TextInput.Password
                    focus: activeState === "cc_wifi_pass"
                }
            }

            Rectangle {
                width: 280; height: 40; radius: 8
                color: pywalColors.accent
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    text: "Connect"
                    color: pywalColors.background
                    font.bold: true
                    font.pixelSize: 14
                    anchors.centerIn: parent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        runSys("nmcli dev wifi connect " + shellQuote(selectedSsid) + " password " + shellQuote(passwordInput.text));
                        passwordInput.text = "";
                        activeState = "clock";
                    }
                }
            }
        }

        // ------------------------------------------
        // D: BLUETOOTH LIST SUBMENU (Paired & Scanned Sections)
        // ------------------------------------------
        Column {
            anchors.fill: parent; anchors.margins: 20; spacing: 10
            opacity: activeState === "cc_bt" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle {
                width: 300; height: 24; color: "transparent"
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: ""; color: pywalColors.primary; font.bold: true; font.pixelSize: 16 }
                    Text { text: "Bluetooth Devices"; color: pywalColors.foreground; font.bold: true; font.pixelSize: 16 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeState = "cc" }
            }

            Flickable {
                width: 300; height: 330
                contentHeight: btContentCol.height
                clip: true

                Column {
                    id: btContentCol
                    width: 300; spacing: 12

                    // --- Paired Devices Section ---
                    Text { text: "Paired Devices"; color: pywalColors.primary; font.bold: true; font.pixelSize: 12 }
                    Repeater {
                        model: pairedBtModel
                        delegate: Rectangle {
                            width: 300; height: 40; radius: 8
                            color: "transparent"
                            border.color: pywalColors.primary; border.width: 1
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 15; spacing: 15
                                Text { text: ""; color: pywalColors.foreground }
                                Text { text: model.name; color: pywalColors.foreground; width: 220; elide: Text.ElideRight }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { 
                                    if(model.mac !== "") { 
                                        runSys("bluetoothctl connect " + model.mac); 
                                        activeState = "clock"; 
                                    } 
                                }
                            }
                        }
                    }

                    Item { height: 5 }

                    // --- Scanned / Available Devices Section ---
                    Text { text: "Available Devices"; color: pywalColors.primary; font.bold: true; font.pixelSize: 12 }
                    Repeater {
                        model: scannedBtModel
                        delegate: Rectangle {
                            width: 300; height: 40; radius: 8
                            color: "transparent"
                            border.color: pywalColors.primary; border.width: 1
                            Row {
                                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 15; spacing: 15
                                Text { text: ""; color: pywalColors.foreground }
                                Text { text: model.name; color: pywalColors.foreground; width: 220; elide: Text.ElideRight }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { 
                                    if(model.mac !== "") { 
                                        runSys("bluetoothctl pair " + model.mac + " && bluetoothctl trust " + model.mac + " && bluetoothctl connect " + model.mac); 
                                        activeState = "clock"; 
                                    } 
                                }
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------
        // E: THE MEDIA PLAYER
        // ------------------------------------------
        Column {
            id: mediaContent
            anchors.fill: parent; anchors.margins: 15; spacing: 15
            opacity: activeState === "media" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            
            property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
            
            Rectangle {
                width: 270; height: 24; color: "transparent"
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: ""; color: pywalColors.accent; font.bold: true; font.pixelSize: 16 }
                    Text { text: "Now Playing"; color: pywalColors.foreground; font.bold: true; font.pixelSize: 16 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: activeState = "clock" }
            }

            Column {
                spacing: 5; anchors.horizontalCenter: parent.horizontalCenter
                Text { text: mediaContent.player ? (mediaContent.player.trackTitle || "Unknown Title") : "No Media Playing"; color: pywalColors.foreground; font.bold: true; font.pixelSize: 16; width: 260; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                Text { text: mediaContent.player ? (mediaContent.player.trackArtist || "") : ""; color: pywalColors.primary; font.pixelSize: 13; width: 260; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; visible: text !== "" }
            }
            Row {
                spacing: 40; anchors.horizontalCenter: parent.horizontalCenter
                Text { text: ""; color: (mediaContent.player && mediaContent.player.canGoPrevious) ? pywalColors.primary : "#555555"; font.pixelSize: 24; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (mediaContent.player && mediaContent.player.canGoPrevious) mediaContent.player.previous() } }
                Text { text: (mediaContent.player && mediaContent.player.isPlaying) ? "" : ""; color: (mediaContent.player && mediaContent.player.canTogglePlaying) ? pywalColors.accent : "#555555"; font.pixelSize: 28; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (mediaContent.player && mediaContent.player.canTogglePlaying) mediaContent.player.togglePlaying() } }
                Text { text: ""; color: (mediaContent.player && mediaContent.player.canGoNext) ? pywalColors.primary : "#555555"; font.pixelSize: 24; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (mediaContent.player && mediaContent.player.canGoNext) mediaContent.player.next() } }
            }
        }
    }
}