import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras

PlasmoidItem {
    id: root

    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    hideOnWindowDeactivate: !Plasmoid.configuration.pinned

    // --- Properties ---
    property string status: "unknown"
    property string statusText: i18n("Checking...")
    property var lastUpdate: new Date()
    property var gpuProcesses: []
    property string nvidiaSmiPath: ""
    property bool hasNvidiaSmi: nvidiaSmiPath !== ""

    property color statusColor: {
        const cfg = plasmoid.configuration;
        if (status === "active") return cfg.activeColor || "#76b900";
        if (status === "suspended") return cfg.suspendedColor || "#888888";
        if (status === "resuming" || status === "suspending") return cfg.resumingColor || "#3daee9";
        return cfg.unknownColor || "#ffaa00";
    }

    // --- Tooltip ---
    toolTipMainText: i18n("NVIDIA GPU Status")
    toolTipSubText: i18n("Current State: %1", statusText)

    // --- Representations ---
    preferredRepresentation: compactRepresentation

    compactRepresentation: MouseArea {
        id: compactRoot
        
        readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        
        Layout.preferredWidth:  isVertical ? -1 : layout.implicitWidth
        Layout.preferredHeight: isVertical ? layout.implicitHeight : -1
        
        hoverEnabled: true

        onPressed: (mouse) => {}
        
        onClicked: (mouse) => {
            root.expanded = !root.expanded;
        }

        RowLayout {
            id: layout
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignCenter
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium

                source: root.status === "active"
                    ? Qt.resolvedUrl("../assets/nvidia-active.svg")
                    : Qt.resolvedUrl("../assets/nvidia-suspended.svg")

                isMask: true
                color: root.statusColor
            }

            PlasmaComponents3.Label {
                visible: (plasmoid.configuration && plasmoid.configuration.showTextInCompact) || false
                text: root.statusText
                color: root.statusColor
                font.bold: true
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: fullRep
        implicitWidth: Kirigami.Units.gridUnit * 22
        implicitHeight: Kirigami.Units.gridUnit * 18

        header: PlasmaExtras.PlasmoidHeading {
            contentHeight: headerLayout.implicitHeight
            RowLayout {
                id: headerLayout
                anchors.fill: parent
                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    text: i18n("NVIDIA Status")
                    level: 2
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "configure-symbolic"
                    display: PlasmaComponents3.ToolButton.IconOnly
                    PlasmaComponents3.ToolTip.text: i18n("Settings")
                    onClicked: Plasmoid.internalAction("configure").trigger()
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "window-pin-symbolic"
                    display: PlasmaComponents3.ToolButton.IconOnly
                    checkable: true
                    checked: Plasmoid.configuration.pinned
                    PlasmaComponents3.ToolTip.text: checked ? i18n("Unpin") : i18n("Pin Open")
                    onToggled: Plasmoid.configuration.pinned = checked
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // Dynamic Status Card
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    implicitWidth: Kirigami.Units.iconSizes.huge
                    implicitHeight: Kirigami.Units.iconSizes.huge
                    source: root.status === "active"
                        ? Qt.resolvedUrl("../assets/nvidia-active.svg")
                        : Qt.resolvedUrl("../assets/nvidia-suspended.svg")
                    isMask: true
                    color: root.statusColor
                }

                ColumnLayout {
                    spacing: 0
                    PlasmaComponents3.Label { text: root.statusText; color: root.statusColor; font.bold: true; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2 }
                    PlasmaComponents3.Label { opacity: 0.6; font.pointSize: Kirigami.Theme.smallFont.pointSize; text: i18n("Updates every %1s", plasmoid.configuration.updateInterval) }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // Process List Section
            ListView {
                id: processList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                headerPositioning: ListView.OverlayHeader
                header: Item {
                    width: processList.width
                    height: Kirigami.Units.gridUnit * 1.5
                    visible: root.gpuProcesses.length > 0
                    
                    readonly property int colWidth: Kirigami.Units.gridUnit * 5
                    readonly property int margin: Kirigami.Units.largeSpacing

                    PlasmaComponents3.Label { 
                        id: headerMem
                        text: i18n("Mem")
                        font.bold: true
                        width: parent.colWidth
                        anchors.right: parent.right
                        anchors.rightMargin: parent.margin
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter 
                    }
                    PlasmaComponents3.Label { 
                        id: headerGpu
                        text: i18n("GPU")
                        font.bold: true
                        width: parent.colWidth
                        anchors.right: headerMem.left
                        anchors.rightMargin: parent.margin
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter 
                    }
                    PlasmaComponents3.Label { 
                        text: i18n("Process Name")
                        font.bold: true
                        anchors.left: parent.left
                        anchors.leftMargin: parent.margin
                        anchors.right: headerGpu.left
                        anchors.rightMargin: parent.margin
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                    }
                }

                model: root.status === "active" ? root.gpuProcesses : []
                visible: root.hasNvidiaSmi && root.status === "active" && root.gpuProcesses.length > 0
                
                delegate: PlasmaComponents3.ItemDelegate {
                    width: processList.width
                    height: Kirigami.Units.gridUnit * 2.5
                    
                    readonly property int colWidth: Kirigami.Units.gridUnit * 5
                    readonly property int margin: Kirigami.Units.largeSpacing

                    contentItem: Item {
                        PlasmaComponents3.Label { 
                            id: dataMem
                            text: modelData.mem + "%"
                            width: parent.parent.colWidth
                            anchors.right: parent.right
                            anchors.rightMargin: parent.parent.margin
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter 
                            color: modelData.mem > 0 ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor 
                        }
                        PlasmaComponents3.Label { 
                            id: dataGpu
                            text: modelData.sm + "%"
                            width: parent.parent.colWidth
                            anchors.right: dataMem.left
                            anchors.rightMargin: parent.parent.margin
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter 
                            color: modelData.sm > 0 ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor 
                        }
                        ColumnLayout {
                            spacing: 0
                            anchors.left: parent.left
                            anchors.leftMargin: parent.parent.margin
                            anchors.right: dataGpu.left
                            anchors.rightMargin: parent.parent.margin
                            anchors.verticalCenter: parent.verticalCenter
                            PlasmaComponents3.Label { 
                                text: modelData.name
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight 
                            }
                            PlasmaComponents3.Label { 
                                text: "PID: " + modelData.pid + " • " + modelData.type
                                opacity: 0.6
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                PlasmaComponents3.Label {
                    anchors.centerIn: parent
                    text: i18n("No apps currently using GPU")
                    opacity: 0.5
                    visible: root.status === "active" && root.gpuProcesses.length === 0
                }
            }

            // Info Placeholders
            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !processList.visible
                icon.name: !root.hasNvidiaSmi ? "error-symbolic" : (root.status === "active" ? "utilities-system-monitor-symbolic" : "system-suspend-symbolic")
                text: !root.hasNvidiaSmi ? i18n("nvidia-smi Not Found") : (root.status === "active" ? i18n("GPU is Active") : i18n("GPU is Suspended"))
                explanation: !root.hasNvidiaSmi 
                    ? i18n("Check your NVIDIA driver installation.") 
                    : (root.status === "active" ? i18n("No active processes detected.") : i18n("Monitoring is paused to save power."))
            }
        }
    }

    // --- Data Source ---
    Plasma5Support.DataSource {
        id: gpuStatusSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            const result = data["stdout"] ? data["stdout"].trim() : "";
            root.status = result;
            root.lastUpdate = new Date();
            // ...

            if (result === "suspended") {
                root.statusText = i18n("Suspended (D3cold)");
                root.gpuProcesses = []; // Clear processes when suspended
            } else if (result === "active") {
                root.statusText = i18n("Active (D0)");
            } else if (result === "resuming") {
                root.statusText = i18n("Resuming...");
            } else if (result === "suspending") {
                root.statusText = i18n("Suspending...");
            } else {
                root.statusText = result || i18n("Unknown");
            }
            disconnectSource(sourceName);
        }
    }

    Plasma5Support.DataSource {
        id: gpuProcessesSource
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            const stdout = data["stdout"] || "";
            // Handle Discovery
            if (sourceName.indexOf("p in") !== -1 || sourceName.indexOf("which") !== -1) {
                const discoveredPath = stdout.trim();
                if (discoveredPath.length > 0) {
                    root.nvidiaSmiPath = discoveredPath;
                }
            } else {
                const lines = stdout.split("\n");
                const processes = [];
                for (let i = 2; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line || line.startsWith("#")) continue;
                    
                    const parts = line.split(/\s+/);
                    
                    if (parts.length >= 10) {
                        const name = parts.slice(9).join(" ").trim();
                        if (name === "" || name === "-") continue;
                        
                        processes.push({
                            "pid": parts[1],
                            "type": parts[2],
                            "sm": parts[3] === "-" ? "0" : parts[3],
                            "mem": parts[4] === "-" ? "0" : parts[4],
                            "name": name
                        });
                    }
                }
                root.gpuProcesses = processes;
            }
            disconnectSource(sourceName);
        }
    }

    Component.onCompleted: {
        // Search in common system paths, user path, and then system-wide which
        gpuProcessesSource.connectSource("for p in /usr/bin/nvidia-smi /usr/local/bin/nvidia-smi ~/.local/bin/nvidia-smi; do [ -x \"$p\" ] && echo \"$p\" && exit 0; done; which nvidia-smi");
    }

    // Refresh processes when expanded
    onExpandedChanged: (expanded) => {
        if (expanded && root.status === "active" && root.hasNvidiaSmi) {
            gpuProcessesSource.disconnectSource(root.nvidiaSmiPath + " pmon -c 1");
            gpuProcessesSource.connectSource(root.nvidiaSmiPath + " pmon -c 1");
        }
    }

    // Safe Timer: Polls every X seconds
    Timer {
        interval: (plasmoid.configuration.updateInterval || 3) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const addr = plasmoid.configuration.pciAddress || "0000:01:00.0";
            gpuStatusSource.disconnectSource("cat /sys/bus/pci/devices/" + addr + "/power/runtime_status");
            gpuStatusSource.connectSource("cat /sys/bus/pci/devices/" + addr + "/power/runtime_status");
            
            // Only query processes if expanded AND gpu is active AND tool was found
            // This is the "No-Wake" Guardian: it prevents nvidia-smi from waking the GPU
            if (root.expanded && root.status === "active" && root.hasNvidiaSmi) {
                const cmd = root.nvidiaSmiPath + " pmon -c 1";
                gpuProcessesSource.disconnectSource(cmd);
                gpuProcessesSource.connectSource(cmd);
            }
        }
    }
}
