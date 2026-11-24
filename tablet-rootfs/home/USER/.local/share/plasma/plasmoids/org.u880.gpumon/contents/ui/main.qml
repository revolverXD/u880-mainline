import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Shows the line written every 2 s by u880-gpu-sample (root service): "<MHz> MHz  <busy>%  <temp>C  [HOT]".
PlasmoidItem {
    id: root
    property string line: "GPU: no data"
    preferredRepresentation: fullRepresentation
    

    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["cat /run/u880-gpu.txt"]
        interval: 2000
        onNewData: (source, data) => {
            const t = (data["stdout"] || "").trim()
            root.line = t.length ? "GPU " + t : "GPU: sampler not running"
        }
    }

    fullRepresentation: PlasmaComponents.Label {
        text: root.line
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.line.indexOf("HOT") >= 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
    }
}
