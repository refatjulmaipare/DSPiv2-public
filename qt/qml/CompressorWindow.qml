import QtQuick 2.15
import QtQuick.Controls 2.15
import "components"

AppWindow {
    id: win
    title: "Output Compressor"
    visible: false
    width: 500
    height: 670 + titlebarHeight
    minimumWidth: 440
    minimumHeight: 580 + titlebarHeight
    fitHeight: header.height + flick.contentHeight

    property int selectedOutput: 0
    property var params: [0, -12, 4, 10, 100, 0, 0]
    property real gainReduction: 0
    property bool hasReadValues: false
    property string message: "Read parameters from the selected output"

    readonly property var outputOptions: {
        var count = bridge.connected ? bridge.numOutputChannels : 9
        var values = []
        for (var i = 0; i < count; i++) values.push("Output " + i)
        return values
    }
    readonly property bool compressorEnabled: params.length === 7 && params[0] >= 0.5

    function updateParam(index, value) {
        var next = params.slice()
        next[index] = value
        params = next
    }

    function readAll() {
        if (!bridge.connected || selectedOutput >= bridge.numOutputChannels) {
            hasReadValues = false
            message = "Connect a DSPi to read parameters"
            return false
        }
        var values = []
        for (var i = 0; i < 7; i++) {
            var value = bridge.getCompressorParam(selectedOutput, i)
            if (!isFinite(value)) {
                hasReadValues = false
                message = "Read failed; check firmware support"
                return false
            }
            values.push(value)
        }
        params = values
        gainReduction = 0
        hasReadValues = true
        message = "Parameters read"
        return true
    }

    function writeAll() {
        if (!bridge.connected || params.length !== 7) return false
        for (var i = 0; i < 7; i++) {
            if (!bridge.setCompressorParam(selectedOutput, i, params[i])) {
                message = "Write failed at parameter " + i
                return false
            }
        }
        hasReadValues = true
        message = "Parameters written"
        return true
    }

    onSelectedOutputChanged: {
        hasReadValues = false
        gainReduction = 0
        message = "Read parameters from the selected output"
    }
    onVisibleChanged: if (visible && !bridge.connected) message = "Connect a DSPi to read parameters"

    Connections {
        target: bridge
        function onStatusChanged() {
            if (!bridge.connected) {
                hasReadValues = false
                gainReduction = 0
                message = "Connect a DSPi to read parameters"
            }
        }
        function onStateChanged() {
            if (bridge.connected && selectedOutput >= bridge.numOutputChannels)
                selectedOutput = Math.max(0, bridge.numOutputChannels - 1)
        }
    }

    ToolHeader {
        id: header
        width: parent.width
        icon: "compressor"
        title: "Output Compressor"
        subtitle: "Per-output dynamics control"
        showSwitch: false
    }

    Flickable {
        id: flick
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        contentHeight: body.height + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: body
            x: 16
            y: 12
            width: flick.width - 32
            spacing: 8

            Row {
                width: parent.width
                height: 30
                spacing: 10
                Text {
                    text: "OUTPUT"
                    width: 54
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: isMacOS ? MacColors.secondaryLabel : Qt.rgba(1, 1, 1, 0.5)
                }
                StyledComboBox {
                    width: 132
                    model: win.outputOptions
                    currentIndex: Math.min(win.selectedOutput, Math.max(0, count - 1))
                    enabled: bridge.connected && count > 0
                    onActivated: win.selectedOutput = currentIndex
                }
                Item { width: 1; height: 1 }
                Text {
                    width: parent.width - 230
                    text: bridge.connected ? bridge.channelName(selectedOutput + 2) : "Not connected"
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 12
                    color: isMacOS ? MacColors.secondaryLabel : Qt.rgba(1, 1, 1, 0.55)
                }
            }

            CompressorGraph {
                width: parent.width
                height: 160
                threshold: win.params[1]
                ratio: win.params[2]
                knee: win.params[5]
                makeup: win.params[6]
                compressorEnabled: win.compressorEnabled
            }

            Text {
                text: "PARAMETERS"
                height: 14
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 0.4
                color: isMacOS ? MacColors.secondaryLabel : Qt.rgba(1, 1, 1, 0.5)
            }

            Item {
                width: parent.width
                height: 28
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Enabled"
                    font.pixelSize: 13
                    color: isMacOS ? MacColors.label : Qt.rgba(1, 1, 1, 0.9)
                }
                ToggleSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: win.params[0] >= 0.5
                    enabled: bridge.connected
                    onToggled: win.updateParam(0, checked ? 1 : 0)
                }
            }

            CompressorParameterRow {
                width: parent.width
                label: "Threshold"; unit: "dB"; decimals: 1
                from: -60; to: 0; value: win.params[1]
                onEdited: win.updateParam(1, value)
            }
            CompressorParameterRow {
                width: parent.width
                label: "Ratio"; unit: ":1"; decimals: 1
                from: 1; to: 20; step: 0.1; value: win.params[2]
                onEdited: win.updateParam(2, value)
            }
            CompressorParameterRow {
                width: parent.width
                label: "Attack"; unit: "ms"; decimals: 1
                from: 0.1; to: 100; step: 0.1; logarithmic: true; value: win.params[3]
                onEdited: win.updateParam(3, value)
            }
            CompressorParameterRow {
                width: parent.width
                label: "Release"; unit: "ms"; decimals: 0
                from: 10; to: 1000; step: 1; logarithmic: true; value: win.params[4]
                onEdited: win.updateParam(4, value)
            }
            CompressorParameterRow {
                width: parent.width
                label: "Knee"; unit: "dB"; decimals: 1
                from: 0; to: 20; value: win.params[5]
                onEdited: win.updateParam(5, value)
            }
            CompressorParameterRow {
                width: parent.width
                label: "Makeup"; unit: "dB"; decimals: 1
                from: 0; to: 20; value: win.params[6]
                onEdited: win.updateParam(6, value)
            }

            Row {
                width: parent.width
                height: 30
                spacing: 10
                Text {
                    text: "GAIN REDUCTION"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: isMacOS ? MacColors.secondaryLabel : Qt.rgba(1, 1, 1, 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: parent.width - reductionText.width - 126
                    height: 6
                    radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, win.gainReduction / 20))
                        height: parent.height
                        radius: parent.radius
                        color: win.gainReduction > 0.05 ? "#ff9f0a" : "#3a96ff"
                    }
                }
                Text {
                    id: reductionText
                    width: 56
                    text: win.gainReduction.toFixed(1) + " dB"
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 12
                    color: win.gainReduction > 0.05 ? "#ff9f0a" : Qt.rgba(1, 1, 1, 0.65)
                }
            }

            Row {
                width: parent.width
                height: 30
                spacing: 8
                AppButton {
                    text: "Read"
                    enabled: bridge.connected && outputOptions.length > 0
                    onClicked: win.readAll()
                }
                AppButton {
                    text: "Write"
                    primary: true
                    enabled: bridge.connected && outputOptions.length > 0
                    onClicked: win.writeAll()
                }
                Text {
                    width: parent.width - 170
                    text: win.message
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 11
                    color: isMacOS ? MacColors.secondaryLabel : Qt.rgba(1, 1, 1, 0.48)
                }
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: win.visible && bridge.connected && win.compressorEnabled && win.hasReadValues
        onTriggered: {
            var value = bridge.getCompressorMeter(win.selectedOutput)
            if (isFinite(value)) win.gainReduction = value
        }
    }

    component CompressorParameterRow: Column {
        id: row
        property string label: ""
        property string unit: ""
        property int decimals: 1
        property real from: 0
        property real to: 1
        property real step: Math.pow(10, -decimals)
        property real value: 0
        property bool logarithmic: false
        signal edited(real value)

        height: 40
        spacing: 0

        function sliderPosition(input) {
            var v = Math.max(from, Math.min(to, input))
            return logarithmic ? Math.log(v / from) / Math.log(to / from) : (v - from) / (to - from)
        }
        function valueAt(position) {
            return logarithmic ? from * Math.pow(to / from, position) : from + position * (to - from)
        }

        Row {
            width: parent.width
            height: 20
            Text {
                text: row.label
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13
                color: isMacOS ? MacColors.label : Qt.rgba(1, 1, 1, 0.9)
            }
            Item { width: parent.width - rowValue.width - 100; height: 1 }
            ValueField {
                id: rowValue
                fieldWidth: 54
                height: 20
                suffix: row.unit
                decimals: row.decimals
                maxDecimals: row.decimals
                wheelStep: row.step
                minValue: row.from
                maxValue: row.to
                value: row.value
                onValueEdited: row.edited(newValue)
            }
        }
        StyledSlider {
            width: parent.width
            height: 20
            from: 0
            to: 1
            value: row.sliderPosition(row.value)
            onMoved: row.edited(row.valueAt(value))
        }
    }
}