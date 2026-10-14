import QtQuick 2.15

Item {
    id: graph
    implicitHeight: 160

    property real threshold: -12
    property real ratio: 4
    property real knee: 0
    property real makeup: 0
    property bool compressorEnabled: true

    function outputLevel(input) {
        if (!compressorEnabled) return input
        var safeRatio = Math.max(1, ratio)
        var width = Math.max(0, knee)
        var compressed = input
        if (width > 0) {
            var lower = threshold - width / 2
            var upper = threshold + width / 2
            if (input > lower && input < upper) {
                compressed = input + (1 / safeRatio - 1) * Math.pow(input - lower, 2) / (2 * width)
            } else if (input >= upper) {
                compressed = threshold + (input - threshold) / safeRatio
            }
        } else if (input > threshold) {
            compressed = threshold + (input - threshold) / safeRatio
        }
        return compressed + makeup
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(1, 1, 1, 0.035)
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Canvas {
            id: plot
            anchors.fill: parent
            anchors.margins: 1

            function xAt(db) { return 32 + (db + 60) / 60 * (width - 44) }
            function yAt(db) { return 10 + (0 - db) / 60 * (height - 34) }

            onPaint: {
                var ctx = getContext("2d")
                var left = 32, top = 10, right = width - 12, bottom = height - 24
                var plotWidth = right - left, plotHeight = bottom - top
                ctx.clearRect(0, 0, width, height)
                ctx.font = "10px sans-serif"
                ctx.lineWidth = 1

                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.45)
                for (var step = 0; step <= 3; step++) {
                    var inputDb = -60 + step * 20
                    var outputDb = 0 - step * 20
                    var x = left + step * plotWidth / 3
                    var y = top + step * plotHeight / 3
                    ctx.beginPath(); ctx.moveTo(x, top); ctx.lineTo(x, bottom); ctx.stroke()
                    ctx.beginPath(); ctx.moveTo(left, y); ctx.lineTo(right, y); ctx.stroke()
                    ctx.fillText(inputDb.toString(), x - 8, bottom + 13)
                    ctx.fillText(outputDb.toString(), 3, y + 3)
                }

                var kneeWidth = Math.max(0, graph.knee)
                if (graph.compressorEnabled && kneeWidth > 0) {
                    var kneeLeft = xAt(Math.max(-60, graph.threshold - kneeWidth / 2))
                    var kneeRight = xAt(Math.min(0, graph.threshold + kneeWidth / 2))
                    ctx.fillStyle = Qt.rgba(0.04, 0.49, 1, 0.08)
                    ctx.fillRect(kneeLeft, top, kneeRight - kneeLeft, plotHeight)
                }

                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.28)
                ctx.beginPath()
                ctx.moveTo(xAt(-60), yAt(-60))
                ctx.lineTo(xAt(0), yAt(0))
                ctx.stroke()

                ctx.strokeStyle = graph.compressorEnabled ? "#3a96ff" : Qt.rgba(1, 1, 1, 0.42)
                ctx.lineWidth = 2
                ctx.beginPath()
                for (var i = 0; i <= 120; i++) {
                    var input = -60 + i * 0.5
                    var output = Math.max(-60, Math.min(0, graph.outputLevel(input)))
                    var px = xAt(input), py = yAt(output)
                    if (i === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                }
                ctx.stroke()

                var pointX = xAt(graph.threshold)
                var pointY = yAt(Math.max(-60, Math.min(0, graph.outputLevel(graph.threshold))))
                ctx.fillStyle = "#ff9f0a"
                ctx.beginPath(); ctx.arc(pointX, pointY, 3.5, 0, Math.PI * 2); ctx.fill()
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.55)
                ctx.fillText("INPUT / OUTPUT dBFS", right - 112, top + 10)
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }

    onThresholdChanged: plot.requestPaint()
    onRatioChanged: plot.requestPaint()
    onKneeChanged: plot.requestPaint()
    onMakeupChanged: plot.requestPaint()
    onCompressorEnabledChanged: plot.requestPaint()
}