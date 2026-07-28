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
    property string sortField: (plasmoid.configuration && plasmoid.configuration.sortField) || "sm"
    property bool sortDescending: plasmoid.configuration && plasmoid.configuration.sortDescending !== undefined ? plasmoid.configuration.sortDescending : true
    property var processHistory: ({})
    property var rawGpuProcesses: []
    property var gpuProcesses: sortProcesses(rawGpuProcesses, sortField, sortDescending)
    property string nvidiaSmiPath: ""
    property bool hasNvidiaSmi: nvidiaSmiPath !== ""
    readonly property string getProcessCmd: root.nvidiaSmiPath + " pmon -c 1; echo \"---PROCESSES---\"; " + root.nvidiaSmiPath
    property int idleBackoffCount: 0
    property double lastSmiQueryTime: 0

    function isUserProcess(proc) {
        if (!proc) return false;
        const rawName = (proc.name || "").toLowerCase();
        let basename = rawName;
        const lastSlash = Math.max(rawName.lastIndexOf("/"), rawName.lastIndexOf("\\"));
        if (lastSlash !== -1) {
            basename = rawName.substring(lastSlash + 1);
        }

        if (basename === "kwin_wayland" || basename === "xwayland" || basename === "systemd" || basename === "plasmashell" || basename === "kwin") {
            return false;
        }
        return true;
    }

    function parseVramInMb(memStr) {
        if (!memStr) return 0;
        const str = memStr.toString().trim();
        const val = parseFloat(str);
        if (isNaN(val)) return 0;
        if (str.indexOf("GiB") !== -1 || str.indexOf("GB") !== -1) {
            return val * 1024;
        }
        return val;
    }

    function sortProcesses(procList, field, descending) {
        if (!procList || !procList.length) return [];
        const listCopy = procList.slice();
        listCopy.sort((a, b) => {
            let valA, valB;
            if (field === "name") {
                valA = (a.name || "").toLowerCase();
                valB = (b.name || "").toLowerCase();
                if (valA < valB) return descending ? 1 : -1;
                if (valA > valB) return descending ? -1 : 1;
                return 0;
            } else if (field === "mem") {
                valA = parseVramInMb(a.mem);
                valB = parseVramInMb(b.mem);
            } else { // "sm" / GPU usage (default)
                valA = parseFloat(a.sm) || 0;
                valB = parseFloat(b.sm) || 0;
            }
            if (valA === valB) {
                return (a.name || "").localeCompare(b.name || "");
            }
            return descending ? (valB - valA) : (valA - valB);
        });
        return listCopy;
    }

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
                    id: headerItem
                    width: processList.width
                    height: Kirigami.Units.gridUnit * 1.5
                    visible: root.gpuProcesses.length > 0
                    
                    readonly property int colWidth: Kirigami.Units.gridUnit * 5
                    readonly property int margin: Kirigami.Units.largeSpacing

                    function getSortIndicator(field) {
                        if (root.sortField !== field) return "";
                        return root.sortDescending ? " ▼" : " ▲";
                    }

                    // Memory Column Header
                    MouseArea {
                        id: headerMemArea
                        width: parent.colWidth
                        height: parent.height
                        anchors.right: parent.right
                        anchors.rightMargin: parent.margin
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (plasmoid.configuration.sortField === "mem") {
                                plasmoid.configuration.sortDescending = !plasmoid.configuration.sortDescending;
                            } else {
                                plasmoid.configuration.sortField = "mem";
                                plasmoid.configuration.sortDescending = true;
                            }
                        }

                        PlasmaComponents3.Label { 
                            id: headerMem
                            text: i18n("Mem") + headerItem.getSortIndicator("mem")
                            font.bold: true
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter 
                            color: headerMemArea.containsMouse || root.sortField === "mem" ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                    }

                    // GPU Column Header
                    MouseArea {
                        id: headerGpuArea
                        width: parent.colWidth
                        height: parent.height
                        anchors.right: headerMemArea.left
                        anchors.rightMargin: parent.margin
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (plasmoid.configuration.sortField === "sm") {
                                plasmoid.configuration.sortDescending = !plasmoid.configuration.sortDescending;
                            } else {
                                plasmoid.configuration.sortField = "sm";
                                plasmoid.configuration.sortDescending = true;
                            }
                        }

                        PlasmaComponents3.Label { 
                            id: headerGpu
                            text: i18n("GPU") + headerItem.getSortIndicator("sm")
                            font.bold: true
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter 
                            color: headerGpuArea.containsMouse || root.sortField === "sm" ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                    }

                    // Process Name Column Header
                    MouseArea {
                        id: headerNameArea
                        height: parent.height
                        anchors.left: parent.left
                        anchors.leftMargin: parent.margin
                        anchors.right: headerGpuArea.left
                        anchors.rightMargin: parent.margin
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (plasmoid.configuration.sortField === "name") {
                                plasmoid.configuration.sortDescending = !plasmoid.configuration.sortDescending;
                            } else {
                                plasmoid.configuration.sortField = "name";
                                plasmoid.configuration.sortDescending = false;
                            }
                        }

                        PlasmaComponents3.Label { 
                            text: i18n("Process Name") + headerItem.getSortIndicator("name")
                            font.bold: true
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            color: headerNameArea.containsMouse || root.sortField === "name" ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
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
                            text: {
                                const m = (modelData.mem || "0").toString();
                                if (m.indexOf("B") !== -1 || m.indexOf("%") !== -1) return m;
                                return m + "%";
                            }
                            width: parent.parent.colWidth
                            anchors.right: parent.right
                            anchors.rightMargin: parent.parent.margin
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter 
                            color: root.parseVramInMb(modelData.mem) > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor 
                        }
                        PlasmaComponents3.Label { 
                            id: dataGpu
                            text: modelData.sm + "%"
                            width: parent.parent.colWidth
                            anchors.right: dataMem.left
                            anchors.rightMargin: parent.parent.margin
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter 
                            color: parseFloat(modelData.sm) > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor 
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
            const oldStatus = root.status;
            const result = data["stdout"] ? data["stdout"].trim() : "";
            root.status = result;
            root.lastUpdate = new Date();

            if (result === "suspended") {
                root.statusText = i18n("Suspended (D3cold)");
                root.processHistory = {};
                root.rawGpuProcesses = []; // Clear processes when suspended
                root.idleBackoffCount = 0;
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
                const partsOut = stdout.split("---PROCESSES---");
                const pmonOut = partsOut[0] || "";
                const smiOut = partsOut[1] || "";

                // 1. Parse pmon data
                const pmonMap = {};
                const pmonLines = pmonOut.split("\n");
                for (let i = 2; i < pmonLines.length; i++) {
                    const line = pmonLines[i].trim();
                    if (!line || line.startsWith("#")) continue;
                    const parts = line.split(/\s+/);
                    if (parts.length >= 10) {
                        const pid = parts[1];
                        const type = parts[2];
                        const sm = parts[3];
                        const mem = parts[4];
                        const name = parts.slice(9).join(" ").trim();
                        if (name && name !== "-") {
                            pmonMap[pid] = { pid, type, sm, mem, name };
                        }
                    }
                }

                // 2. Parse standard nvidia-smi process table data & overall GPU utilization
                let overallGpuUtil = null;
                const processMap = {};
                const smiLines = smiOut.split("\n");
                const procRegex = /\|\s*\d+\s+(?:N\/A|\d+)\s+(?:N\/A|\d+)\s+(\d+)\s+(\S+)\s+(.*?)\s+(\d+(?:\.\d+)?\s*(?:MiB|MB|GiB|GB))\s*\|/;

                for (let i = 0; i < smiLines.length; i++) {
                    const line = smiLines[i];
                    if (line.indexOf("MiB /") !== -1 || line.indexOf("GiB /") !== -1 || line.indexOf("MB /") !== -1) {
                        const matchUtil = line.match(/\|\s*(\d+)%\s+(?:Default|Exclusive|Prohibited|Process)/);
                        if (matchUtil) {
                            overallGpuUtil = parseFloat(matchUtil[1]);
                        }
                    }

                    const match = line.match(procRegex);
                    if (match) {
                        const pid = match[1];
                        const type = match[2];
                        let name = match[3].trim();
                        const vram = match[4].trim();

                        if (name.lastIndexOf("\\") !== -1) {
                            name = name.substring(name.lastIndexOf("\\") + 1);
                        } else if (name.lastIndexOf("/") !== -1) {
                            name = name.substring(name.lastIndexOf("/") + 1);
                        }

                        processMap[pid] = { pid, type, name, vram };
                    }
                }

                // If smiOut didn't return process lines, fallback to pmon processes
                for (const pid in pmonMap) {
                    if (!processMap[pid]) {
                        processMap[pid] = {
                            pid: pid,
                            type: pmonMap[pid].type,
                            name: pmonMap[pid].name,
                            vram: pmonMap[pid].mem !== "-" ? pmonMap[pid].mem + "%" : "0 MB"
                        };
                    }
                }

                // Count active user processes
                let totalUserProcs = 0;
                for (const pid in processMap) {
                    if (root.isUserProcess(processMap[pid])) {
                        totalUserProcs++;
                    }
                }

                // 3. Build merged process list with smoothing and overall GPU utilization fallback
                const newHistory = {};
                const finalProcesses = [];

                for (const pid in processMap) {
                    const item = processMap[pid];
                    const pmonItem = pmonMap[pid];

                    let name = item.name;
                    if (pmonItem && pmonItem.name && pmonItem.name.length > 0 && name.indexOf("...") !== -1) {
                        name = pmonItem.name;
                    }

                    let rawSm = pmonItem ? pmonItem.sm : "-";
                    let smVal = (rawSm === "-" || rawSm === undefined) ? null : parseFloat(rawSm);
                    if (isNaN(smVal)) smVal = null;

                    const key = pid; // Use stable PID key
                    const prev = root.processHistory[key];

                    let smGrace = 0;

                    if (smVal !== null && smVal > 0) {
                        smGrace = 0;
                    } else if (prev && prev.sm > 0 && prev.smGrace < 30) {
                        smVal = prev.sm;
                        smGrace = prev.smGrace + 1;
                    } else if (root.isUserProcess(item) && overallGpuUtil !== null && overallGpuUtil > 0) {
                        // Fallback: If pmon reports 0% for a active user process, use overall GPU utilization
                        smVal = (totalUserProcs > 1) ? Math.round(overallGpuUtil / totalUserProcs) : overallGpuUtil;
                        smGrace = 0;
                    }

                    const finalSm = (smVal !== null && !isNaN(smVal)) ? smVal : 0;
                    const finalMem = item.vram || (pmonItem && pmonItem.mem !== "-" ? pmonItem.mem + "%" : "0 MB");

                    newHistory[key] = {
                        sm: finalSm,
                        smGrace: smGrace,
                        vram: finalMem
                    };

                    finalProcesses.push({
                        "pid": pid,
                        "type": item.type,
                        "sm": finalSm.toString(),
                        "mem": finalMem,
                        "name": name
                    });
                }

                let userProcCount = 0;
                for (let i = 0; i < finalProcesses.length; i++) {
                    if (root.isUserProcess(finalProcesses[i])) {
                        userProcCount++;
                    }
                }

                if (userProcCount === 0) {
                    root.idleBackoffCount = 1;
                } else {
                    root.idleBackoffCount = 0;
                }

                root.processHistory = newHistory;
                root.rawGpuProcesses = finalProcesses;
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
            root.idleBackoffCount = 0;
            root.lastSmiQueryTime = Date.now();
            gpuProcessesSource.disconnectSource(root.getProcessCmd);
            gpuProcessesSource.connectSource(root.getProcessCmd);
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
            
            // Only query processes if expanded AND gpu is active AND tool was found AND user processes exist (idleBackoffCount < 1)
            // This is the "No-Wake" Guardian: stops nvidia-smi to allow Linux PCI runtime PM to auto-suspend the GPU
            if (root.expanded && root.status === "active" && root.hasNvidiaSmi) {
                if (root.idleBackoffCount < 1) {
                    gpuProcessesSource.disconnectSource(root.getProcessCmd);
                    gpuProcessesSource.connectSource(root.getProcessCmd);
                }
            }
        }
    }
}
