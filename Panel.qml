import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar pill + popup showing live CPU/GPU/RAM/storage usage and temperature.
// All the sampling lives in bin/omarchy-sysmon-stats, bundled with this
// plugin and driven straight by this widget's own Timer.
Panel {
  id: root
  moduleName: "santyalmeida.sysmon"
  ipcTarget: "santyalmeida.sysmon"

  readonly property string statsScript: String(Qt.resolvedUrl("bin/omarchy-sysmon-stats")).replace("file://", "")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: Color.urgent
  readonly property color warn: Qt.lighter(Color.urgent, 1.35)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent, Color.urgent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Nerd Font glyphs, verified against the installed font's cmap/post
  // tables (JetBrainsMono Nerd Font): md-harddisk U+F02CA, md-memory
  // U+F035B (both outside the BMP, hence fromCodePoint), fa-hdd_o U+F0A0.
  readonly property string iconHdd: String.fromCodePoint(0xF02CA)
  readonly property string iconSsd: String.fromCodePoint(0xF035B)
  readonly property string iconDiskGeneric: String.fromCodePoint(0xF0A0)
  readonly property real diskTileWidth: Style.space(96)

  property var stats: ({})
  readonly property bool hasData: stats && stats.cpu !== undefined
  readonly property var cpu: stats.cpu || null
  readonly property var mem: stats.mem || null
  readonly property var gpu: stats.gpu || null
  readonly property var disks: stats.disks || []

  readonly property real cpuPercent: cpu ? Number(cpu.percent || 0) : 0

  function clamp01(v) { return Math.max(0, Math.min(1, v)) }

  function fmtPercent(p) {
    return (p === null || p === undefined || isNaN(Number(p))) ? "—" : Math.round(Number(p)) + "%"
  }

  function fmtTemp(t) {
    return (t === null || t === undefined) ? "—" : Math.round(Number(t)) + "°C"
  }

  function fmtBytes(b) {
    var n = Number(b || 0)
    if (n >= 1073741824) return (n / 1073741824).toFixed(1) + " GiB"
    if (n >= 1048576) return (n / 1048576).toFixed(0) + " MiB"
    if (n >= 1024) return (n / 1024).toFixed(0) + " KiB"
    return Math.round(n) + " B"
  }

  function fmtMiB(m) {
    var n = Number(m || 0)
    return n >= 1024 ? (n / 1024).toFixed(1) + " GiB" : Math.round(n) + " MiB"
  }

  function tempColor(t, warnAt, critAt) {
    if (t === null || t === undefined) return root.foreground
    var n = Number(t)
    if (n >= critAt) return root.urgent
    if (n >= warnAt) return root.warn
    return root.foreground
  }

  function isHot(t, limit) { return t !== null && t !== undefined && Number(t) >= limit }

  readonly property bool anyHot: {
    if (isHot(cpu ? cpu.tempC : null, 85)) return true
    if (isHot(gpu ? gpu.tempC : null, 88)) return true
    for (var i = 0; i < disks.length; i++) if (isHot(disks[i].tempC, 58)) return true
    return false
  }

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statsProc
    command: [root.statsScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || ""))
          if (parsed && typeof parsed === "object") root.stats = parsed
        } catch (e) { /* keep last good snapshot */ }
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " " + (root.hasData ? Math.round(root.cpuPercent) + "%" : "…")
    slotSize: Style.bar.iconSlot * 1.9
    tooltipText: "System Monitor"
    useActiveColor: root.anyHot
    activeColor: root.urgent
    active: root.anyHot
    onPressed: root.toggle()
  }

  component StatMeter: Item {
    id: meter
    property string label: ""
    property real value: 0
    property string trailing: ""
    property color fillColor: root.foreground

    width: parent ? parent.width : implicitWidth
    implicitHeight: labelRow.implicitHeight + Style.spacing.xs + track.implicitHeight

    Row {
      id: labelRow
      width: parent.width

      Text {
        text: meter.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        width: parent.width - trailingText.implicitWidth
        elide: Text.ElideRight
      }

      Text {
        id: trailingText
        text: meter.trailing
        color: Qt.darker(root.foreground, 1.25)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignRight
      }
    }

    Item {
      id: track
      anchors.top: labelRow.bottom
      anchors.topMargin: Style.spacing.xs
      width: parent.width
      implicitHeight: Math.max(Style.space(4), Style.spacing.sm)
      height: implicitHeight

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.track
      }

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: height / 2
        width: parent.width * root.clamp01(meter.value)
        color: meter.fillColor

        Behavior on width {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  component InfoRow: Row {
    property string label: ""
    property string value: ""
    property color valueColor: root.foreground

    width: parent ? parent.width : implicitWidth

    Text {
      text: label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      width: parent.width - valueText.implicitWidth
    }

    Text {
      id: valueText
      text: value
      color: valueColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
  }

  component RingMeter: Item {
    id: ring
    property real value: 0
    property string centerText: ""
    property color fillColor: root.foreground

    readonly property real diameter: Style.space(56)
    readonly property real ringWidth: Style.space(5)

    implicitWidth: diameter
    implicitHeight: diameter

    Behavior on value {
      NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Shape {
      anchors.fill: parent
      antialiasing: true
      preferredRendererType: Shape.CurveRenderer

      // Track: full ring, always visible, dim.
      ShapePath {
        strokeWidth: ring.ringWidth
        strokeColor: root.track
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathAngleArc {
          centerX: ring.width / 2
          centerY: ring.height / 2
          radiusX: (ring.diameter - ring.ringWidth) / 2
          radiusY: (ring.diameter - ring.ringWidth) / 2
          startAngle: -90
          sweepAngle: 360
        }
      }

      // Value: fills clockwise from the top.
      ShapePath {
        strokeWidth: ring.ringWidth
        strokeColor: ring.value > 0.004 ? ring.fillColor : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathAngleArc {
          centerX: ring.width / 2
          centerY: ring.height / 2
          radiusX: (ring.diameter - ring.ringWidth) / 2
          radiusY: (ring.diameter - ring.ringWidth) / 2
          startAngle: -90
          sweepAngle: 360 * root.clamp01(ring.value)
        }
      }
    }

    Text {
      anchors.centerIn: parent
      text: ring.centerText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  // Column forbids vertical/fill anchors on its own children, so the
  // hover MouseArea can't live inside `content` -- it sits beside it as
  // a plain Item child instead, free to anchors.fill this wrapper.
  component DiskTile: Item {
    id: tile
    required property var modelData

    readonly property real pct: modelData.percent
    readonly property bool hot: root.isHot(modelData.tempC, 58)
    readonly property string glyph: modelData.kind === "hdd" ? root.iconHdd
                                    : modelData.kind === "ssd" ? root.iconSsd
                                    : root.iconDiskGeneric

    implicitHeight: content.implicitHeight
    height: implicitHeight

    Column {
      id: content
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.spacing.xs

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.spacing.xs

        Text {
          text: tile.glyph
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          text: tile.modelData.device
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          width: Math.min(implicitWidth, root.diskTileWidth - Style.space(20))
        }
      }

      RingMeter {
        anchors.horizontalCenter: parent.horizontalCenter
        value: (tile.pct !== null && tile.pct !== undefined) ? tile.pct / 100 : 0
        fillColor: tile.hot ? root.urgent : root.foreground
        centerText: root.fmtPercent(tile.pct)
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.fmtTemp(tile.modelData.tempC)
        color: root.tempColor(tile.modelData.tempC, 48, 58)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      id: tileHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton

      PanelToolTip {
        visible: tileHover.containsMouse
        text: "/dev/" + tile.modelData.device + (tile.modelData.model ? "  ·  " + tile.modelData.model : "")
        fontFamily: root.fontFamily
      }
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    contentWidth: fittedContentWidth(Style.space(340))
    contentHeight: fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.spacing.lg

      Text {
        text: "System Monitor"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      // -------------------------------------------------------------- CPU
      Column {
        width: parent.width
        spacing: Style.spacing.sm

        PanelSectionHeader {
          foreground: root.foreground
          fontFamily: root.fontFamily
          text: "CPU" + (root.cpu && root.cpu.model ? " · " + root.cpu.model : "")
        }

        StatMeter {
          label: "Usage"
          value: root.cpu ? root.cpu.percent / 100 : 0
          trailing: root.fmtPercent(root.cpu ? root.cpu.percent : null)
          fillColor: root.cpu && root.isHot(root.cpu.tempC, 85) ? root.urgent : root.foreground
        }

        InfoRow {
          label: "Temperature"
          value: root.fmtTemp(root.cpu ? root.cpu.tempC : null)
          valueColor: root.tempColor(root.cpu ? root.cpu.tempC : null, 75, 85)
        }
      }

      // -------------------------------------------------------------- GPU
      Column {
        width: parent.width
        spacing: Style.spacing.sm
        visible: !!root.gpu

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          foreground: root.foreground
          fontFamily: root.fontFamily
          text: "GPU" + (root.gpu && root.gpu.name ? " · " + root.gpu.name : "")
        }

        StatMeter {
          label: "Usage"
          value: root.gpu ? root.gpu.percent / 100 : 0
          trailing: root.fmtPercent(root.gpu ? root.gpu.percent : null)
        }

        InfoRow {
          label: "Temperature"
          value: root.fmtTemp(root.gpu ? root.gpu.tempC : null)
          valueColor: root.tempColor(root.gpu ? root.gpu.tempC : null, 80, 88)
        }

        StatMeter {
          label: "VRAM"
          value: root.gpu && root.gpu.vramTotalMiB ? root.gpu.vramUsedMiB / root.gpu.vramTotalMiB : 0
          trailing: root.gpu ? root.fmtMiB(root.gpu.vramUsedMiB) + " / " + root.fmtMiB(root.gpu.vramTotalMiB) : "—"
        }
      }

      // ----------------------------------------------------------- Memory
      Column {
        width: parent.width
        spacing: Style.spacing.sm

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          foreground: root.foreground
          fontFamily: root.fontFamily
          text: "MEMORY"
        }

        StatMeter {
          label: "RAM"
          value: root.mem ? root.mem.percent / 100 : 0
          trailing: root.mem ? root.fmtBytes(root.mem.usedBytes) + " / " + root.fmtBytes(root.mem.totalBytes) : "—"
        }

        StatMeter {
          visible: !!root.mem && root.mem.swapTotalBytes > 0
          label: "Swap"
          value: root.mem ? root.mem.swapPercent / 100 : 0
          trailing: root.mem ? root.fmtBytes(root.mem.swapUsedBytes) + " / " + root.fmtBytes(root.mem.swapTotalBytes) : "—"
        }
      }

      // ---------------------------------------------------------- Storage
      Column {
        width: parent.width
        spacing: Style.spacing.md
        visible: root.disks.length > 0

        PanelSeparator { foreground: root.foreground }

        PanelSectionHeader {
          foreground: root.foreground
          fontFamily: root.fontFamily
          text: "STORAGE"
        }

        Grid {
          id: diskGrid
          width: parent.width
          spacing: Style.spacing.md
          horizontalItemAlignment: Grid.AlignHCenter
          columns: Math.max(1, Math.min(3, root.disks.length,
                                         Math.floor((width + spacing) / (root.diskTileWidth + spacing))))

          Repeater {
            model: root.disks

            DiskTile {
              width: root.diskTileWidth
            }
          }
        }
      }
    }
  }
}
