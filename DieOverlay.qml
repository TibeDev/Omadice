import QtQuick
import QtQuick3D
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

OverlayWindow {
    id: root

    property bool rolling: false
    property bool settling: false
    property bool landed: false
    property bool activeThrow: false
    property bool pendingThrow: false
    property real throwPower: 1
    property string diceTheme: "normal"
    property real positionX: 0
    property real positionY: 0
    property real velocityX: 0
    property real velocityY: 0
    property vector3d angularVelocity: Qt.vector3d(0, 0, 0)
    property quaternion orientation: Qt.quaternion(1, 0, 0, 0)
    property real elapsed: 0
    property real settlingTime: 0
    property int bounceCount: 0
    property int restFrames: 0
    property int rollGeneration: 0
    property int resultValue: 0

    readonly property real dieSize: Math.max(64, Math.min(180, Math.min(width, height) * 0.2))
    readonly property color dieFaceColor: diceTheme === "theme" ? Color.background
        : diceTheme === "inverted" ? Color.foreground : "#f4f4f4"
    readonly property color dieMarkColor: diceTheme === "theme" ? Color.foreground
        : diceTheme === "inverted" ? Color.background : "#171717"

    shown: true
    shownKeyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "tibevdb-dice"
    mask: Region {}

    function throwDice() {
        if (rolling || settling || pendingThrow) {
            dismissDice()
            return
        }

        startNewThrow()
    }

    function startNewThrow() {
        restTimer.stop()
        rollGeneration++
        rolling = false
        settling = false
        landed = false
        resultValue = 0
        positionX = 0
        positionY = 0
        velocityX = 0
        velocityY = 0
        angularVelocity = Qt.vector3d(0, 0, 0)
        pendingThrow = true
        activeThrow = true
        var nextScreen = focusedScreen()
        if (nextScreen)
            targetScreen = nextScreen
        if (contentReady)
            beginThrow()
    }

    function projectedHalfExtents() {
        var sideX = orientation.times(Qt.vector3d(1, 0, 0))
        var sideY = orientation.times(Qt.vector3d(0, 1, 0))
        var sideZ = orientation.times(Qt.vector3d(0, 0, 1))
        var halfSize = dieSize * 0.5
        var edgeMargin = dieSize * 0.005

        return {
            x: halfSize * (Math.abs(sideX.x) + Math.abs(sideY.x) + Math.abs(sideZ.x)) + edgeMargin,
            y: halfSize * (Math.abs(sideX.y) + Math.abs(sideY.y) + Math.abs(sideZ.y)) + edgeMargin
        }
    }

    function vec(x, y, z) {
        return { x: x, y: y, z: z }
    }

    function add(a, b) {
        return vec(a.x + b.x, a.y + b.y, a.z + b.z)
    }

    function subtract(a, b) {
        return vec(a.x - b.x, a.y - b.y, a.z - b.z)
    }

    function multiply(a, factor) {
        return vec(a.x * factor, a.y * factor, a.z * factor)
    }

    function dot(a, b) {
        return a.x * b.x + a.y * b.y + a.z * b.z
    }

    function cross(a, b) {
        return vec(a.y * b.z - a.z * b.y,
                   a.z * b.x - a.x * b.z,
                   a.x * b.y - a.y * b.x)
    }

    function length(a) {
        return Math.sqrt(dot(a, a))
    }

    function randomSpin() {
        return (5 + Math.random() * 8) * (Math.random() < 0.5 ? -1 : 1)
    }

    function makeOrientation(xAngle, yAngle, zAngle) {
        var xHalf = xAngle * Math.PI / 360
        var yHalf = yAngle * Math.PI / 360
        var zHalf = zAngle * Math.PI / 360
        var qx = Qt.quaternion(Math.cos(xHalf), Math.sin(xHalf), 0, 0)
        var qy = Qt.quaternion(Math.cos(yHalf), 0, Math.sin(yHalf), 0)
        var qz = Qt.quaternion(Math.cos(zHalf), 0, 0, Math.sin(zHalf))
        return qz.times(qy).times(qx).normalized()
    }

    function integrateOrientation(dt) {
        var speed = length(vec(angularVelocity.x, angularVelocity.y, angularVelocity.z))
        if (speed < 0.0001)
            return

        var halfAngle = speed * dt * 0.5
        var factor = Math.sin(halfAngle) / speed
        var delta = Qt.quaternion(
            Math.cos(halfAngle),
            angularVelocity.x * factor,
            angularVelocity.y * factor,
            angularVelocity.z * factor
        )
        orientation = delta.times(orientation).normalized()
    }

    function faceTowardCamera() {
        var faces = [
            { value: 1, normal: Qt.vector3d(0, 0, 1) },
            { value: 6, normal: Qt.vector3d(0, 0, -1) },
            { value: 3, normal: Qt.vector3d(1, 0, 0) },
            { value: 4, normal: Qt.vector3d(-1, 0, 0) },
            { value: 2, normal: Qt.vector3d(0, 1, 0) },
            { value: 5, normal: Qt.vector3d(0, -1, 0) }
        ]
        var bestValue = 1
        var bestZ = -Infinity

        for (var i = 0; i < faces.length; i++) {
            var normal = orientation.times(faces[i].normal)
            if (normal.z > bestZ) {
                bestZ = normal.z
                bestValue = faces[i].value
            }
        }

        return bestValue
    }

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, value))
    }

    function beginThrow() {
        if (!pendingThrow || !contentReady)
            return

        pendingThrow = false
        orientation = makeOrientation(Math.random() * 360, Math.random() * 360, Math.random() * 360)
        var extent = projectedHalfExtents()
        var edge = Math.floor(Math.random() * 3)
        var tangent = Math.random()

        if (edge === 0) {
            positionX = -width / 2 + extent.x
            positionY = height / 2 - (extent.y + tangent * Math.max(0, height - extent.y * 2))
            velocityX = width * (0.5 + Math.random() * 0.3)
            velocityY = (Math.random() - 0.5) * height * 0.8
        } else if (edge === 1) {
            positionX = width / 2 - extent.x
            positionY = height / 2 - (extent.y + tangent * Math.max(0, height - extent.y * 2))
            velocityX = -width * (0.5 + Math.random() * 0.3)
            velocityY = (Math.random() - 0.5) * height * 0.8
        } else if (edge === 2) {
            positionX = -width / 2 + extent.x + tangent * Math.max(0, width - extent.x * 2)
            positionY = height / 2 - extent.y
            velocityX = (Math.random() - 0.5) * width * 0.8
            velocityY = -height * (0.5 + Math.random() * 0.3)
        }

        velocityX *= throwPower
        velocityY *= throwPower
        angularVelocity = Qt.vector3d(randomSpin() * throwPower, randomSpin() * throwPower, randomSpin() * throwPower)
        elapsed = 0
        settlingTime = 0
        bounceCount = 0
        restFrames = 0
        resultValue = 0
        settling = false
        rolling = true
    }

    function resolveWall(nx, ny, nz, planeDistance, restitution, friction) {
        var normal = vec(nx, ny, nz)
        var sideX = orientation.times(Qt.vector3d(1, 0, 0))
        var sideY = orientation.times(Qt.vector3d(0, 1, 0))
        var sideZ = orientation.times(Qt.vector3d(0, 0, 1))
        var halfSize = dieSize * 0.5
        var edgeMargin = dieSize * 0.005
        var support = halfSize * (Math.abs(dot(normal, sideX))
            + Math.abs(dot(normal, sideY)) + Math.abs(dot(normal, sideZ))) + edgeMargin
        var center = vec(positionX, positionY, 0)
        var penetration = planeDistance + support - dot(center, normal)

        if (penetration <= 0)
            return false

        positionX += nx * penetration
        positionY += ny * penetration

        var localNormal = orientation.inverted().times(Qt.vector3d(nx, ny, nz))
        var localContact = Qt.vector3d(
            localNormal.x > 0.0001 ? -halfSize : localNormal.x < -0.0001 ? halfSize : 0,
            localNormal.y > 0.0001 ? -halfSize : localNormal.y < -0.0001 ? halfSize : 0,
            localNormal.z > 0.0001 ? -halfSize : localNormal.z < -0.0001 ? halfSize : 0
        )
        var rotatedContact = orientation.times(localContact)
        var arm = vec(rotatedContact.x, rotatedContact.y, rotatedContact.z)
        var omega = vec(angularVelocity.x, angularVelocity.y, angularVelocity.z)
        var velocity = vec(velocityX, velocityY, 0)
        var contactVelocity = add(velocity, cross(omega, arm))
        var normalSpeed = dot(contactVelocity, normal)

        if (normalSpeed >= 0)
            return true

        var inverseInertia = 6 / (dieSize * dieSize)
        var armCrossNormal = cross(arm, normal)
        var normalDenominator = 1 + dot(armCrossNormal, armCrossNormal) * inverseInertia
        var impactSpeed = -normalSpeed
        var bounceFactor = clamp((impactSpeed - 30) / 390, 0, 1)
        var effectiveRestitution = settling ? 0 : restitution * bounceFactor * bounceFactor
        var normalImpulse = -(1 + effectiveRestitution) * normalSpeed / normalDenominator
        var impulse = multiply(normal, normalImpulse)
        var tangentVelocity = subtract(contactVelocity, multiply(normal, normalSpeed))
        var tangentSpeed = length(tangentVelocity)

        if (tangentSpeed > 0.001) {
            var tangent = multiply(tangentVelocity, 1 / tangentSpeed)
            var armCrossTangent = cross(arm, tangent)
            var tangentDenominator = 1 + dot(armCrossTangent, armCrossTangent) * inverseInertia
            var tangentImpulse = Math.min(tangentSpeed / tangentDenominator, friction * normalImpulse)
            impulse = subtract(impulse, multiply(tangent, tangentImpulse))
        }

        velocity = add(velocity, impulse)
        omega = add(omega, multiply(cross(arm, impulse), inverseInertia))
        velocityX = velocity.x
        velocityY = velocity.y
        angularVelocity = Qt.vector3d(omega.x, omega.y, omega.z)

        if (normalSpeed < -90)
            bounceCount++
        return true
    }

    function enterSettle() {
        if (!rolling)
            return

        rolling = false
        settling = true
        settlingTime = 0
        restFrames = 0
        velocityX *= 0.45
        velocityY = Math.min(velocityY, 0) * 0.35
        var slowerSpin = multiply(vec(angularVelocity.x, angularVelocity.y, angularVelocity.z), 0.45)
        angularVelocity = Qt.vector3d(slowerSpin.x, slowerSpin.y, slowerSpin.z)
    }

    function step() {
        var dt = 0.016
        elapsed += dt
        if (settling)
            settlingTime += dt

        velocityY -= 1700 * dt
        positionX += velocityX * dt
        positionY += velocityY * dt
        integrateOrientation(dt)

        var damping = settling ? 0.93 : 0.9995
        velocityX *= settling ? 0.94 : 0.999
        var dampedSpin = multiply(vec(angularVelocity.x, angularVelocity.y, angularVelocity.z), damping)
        angularVelocity = Qt.vector3d(dampedSpin.x, dampedSpin.y, dampedSpin.z)

        resolveWall(1, 0, 0, -width / 2, 0.52, 0.35)
        resolveWall(-1, 0, 0, -width / 2, 0.52, 0.35)
        resolveWall(0, -1, 0, -height / 2, 0.42, 0.4)
        resolveWall(0, 1, 0, -height / 2, 0.34, 0.9)

        var extent = projectedHalfExtents()
        var onFloor = positionY <= -height / 2 + extent.y + 0.5
        var linearSpeed = length(vec(velocityX, velocityY, 0))
        var angularSpeed = length(vec(angularVelocity.x, angularVelocity.y, angularVelocity.z))

        if (settling && onFloor) {
            if (Math.abs(velocityX) < 18)
                velocityX = 0
            if (Math.abs(velocityY) < 35)
                velocityY = 0
            if (angularSpeed < 0.35)
                angularVelocity = Qt.vector3d(0, 0, 0)
        }

        if (rolling && ((bounceCount >= 3 && onFloor && linearSpeed < 70 && angularSpeed < 1.2) || elapsed > 8))
            enterSettle()

        if (settling) {
            var settledLinearSpeed = length(vec(velocityX, velocityY, 0))
            var settledAngularSpeed = length(vec(angularVelocity.x, angularVelocity.y, angularVelocity.z))
            if (onFloor && settledLinearSpeed < 14 && settledAngularSpeed < 0.24)
                restFrames++
            else
                restFrames = 0

            if (restFrames >= 3) {
                finishLanding()
            } else if (settlingTime > 2) {
                velocityX = 0
                velocityY = 0
                angularVelocity = Qt.vector3d(0, 0, 0)
                positionY = -height / 2 + extent.y
                finishLanding()
            }
        }
    }

    function dismissDice() {
        restTimer.stop()
        rollGeneration++
        rolling = false
        settling = false
        pendingThrow = false
        activeThrow = false
        landed = false
        velocityX = 0
        velocityY = 0
        angularVelocity = Qt.vector3d(0, 0, 0)
        resultValue = 0
    }

    function finishLanding(inPlace) {
        var extent = projectedHalfExtents()
        positionX = clamp(positionX, -width / 2 + extent.x, width / 2 - extent.x)
        positionY = inPlace
            ? clamp(positionY, -height / 2 + extent.y, height / 2 - extent.y)
            : -height / 2 + extent.y
        velocityX = 0
        velocityY = 0
        angularVelocity = Qt.vector3d(0, 0, 0)
        rolling = false
        settling = false
        landed = true
        resultValue = faceTowardCamera()
        restTimer.generation = rollGeneration
        restTimer.restart()
    }

    onContentReadyChanged: {
        if (contentReady && pendingThrow)
            beginThrow()
    }

    Timer {
        interval: 16
        repeat: true
        running: root.rolling || root.settling
        onTriggered: root.step()
    }

    Timer {
        id: restTimer
        property int generation: 0
        interval: 2400
        onTriggered: {
            if (generation === root.rollGeneration) {
                root.landed = false
                root.activeThrow = false
            }
        }
    }

    View3D {
        anchors.fill: parent
        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        OrthographicCamera {
            id: camera
            position: Qt.vector3d(0, 0, 1000)
            horizontalMagnification: 1
            verticalMagnification: 1
        }

        camera: camera

        Node {
            id: die
            visible: root.activeThrow
                position: Qt.vector3d(
                    root.positionX,
                    root.positionY,
                    0
                )
            rotation: root.orientation
            scale: Qt.vector3d(root.dieSize / 100, root.dieSize / 100, root.dieSize / 100)

            Model {
                source: "#Cube"
                materials: PrincipledMaterial {
                    baseColor: root.dieFaceColor
                    lighting: PrincipledMaterial.NoLighting
                }
            }

            DiePip { position: Qt.vector3d(0, 0, 50.05); pipColor: root.dieMarkColor }

            DiePip { position: Qt.vector3d(-22, -22, -50.05); pipColor: root.dieMarkColor }
            DiePip { position: Qt.vector3d(0, -22, -50.05); pipColor: root.dieMarkColor }
            DiePip { position: Qt.vector3d(22, -22, -50.05); pipColor: root.dieMarkColor }
            DiePip { position: Qt.vector3d(-22, 22, -50.05); pipColor: root.dieMarkColor }
            DiePip { position: Qt.vector3d(0, 22, -50.05); pipColor: root.dieMarkColor }
            DiePip { position: Qt.vector3d(22, 22, -50.05); pipColor: root.dieMarkColor }

            DiePip { axis: "x"; position: Qt.vector3d(50.05, -22, 22); pipColor: root.dieMarkColor }
            DiePip { axis: "x"; position: Qt.vector3d(50.05, 0, 0); pipColor: root.dieMarkColor }
            DiePip { axis: "x"; position: Qt.vector3d(50.05, 22, -22); pipColor: root.dieMarkColor }

            DiePip { axis: "x"; position: Qt.vector3d(-50.05, -22, -22); pipColor: root.dieMarkColor }
            DiePip { axis: "x"; position: Qt.vector3d(-50.05, -22, 22); pipColor: root.dieMarkColor }
            DiePip { axis: "x"; position: Qt.vector3d(-50.05, 22, -22); pipColor: root.dieMarkColor }
            DiePip { axis: "x"; position: Qt.vector3d(-50.05, 22, 22); pipColor: root.dieMarkColor }

            DiePip { axis: "y"; position: Qt.vector3d(-22, 50.05, -22); pipColor: root.dieMarkColor }
            DiePip { axis: "y"; position: Qt.vector3d(22, 50.05, 22); pipColor: root.dieMarkColor }

            DiePip { axis: "y"; position: Qt.vector3d(-22, -50.05, -22); pipColor: root.dieMarkColor }
            DiePip { axis: "y"; position: Qt.vector3d(22, -50.05, -22); pipColor: root.dieMarkColor }
            DiePip { axis: "y"; position: Qt.vector3d(0, -50.05, 0); pipColor: root.dieMarkColor }
            DiePip { axis: "y"; position: Qt.vector3d(-22, -50.05, 22); pipColor: root.dieMarkColor }
            DiePip { axis: "y"; position: Qt.vector3d(22, -50.05, 22); pipColor: root.dieMarkColor }

            DieEdge { axis: "x"; sideA: -1; sideB: -1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "x"; sideA: -1; sideB: 1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "x"; sideA: 1; sideB: -1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "x"; sideA: 1; sideB: 1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "y"; sideA: -1; sideB: -1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "y"; sideA: -1; sideB: 1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "y"; sideA: 1; sideB: -1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "y"; sideA: 1; sideB: 1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "z"; sideA: -1; sideB: -1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "z"; sideA: -1; sideB: 1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "z"; sideA: 1; sideB: -1; edgeColor: root.dieMarkColor }
            DieEdge { axis: "z"; sideA: 1; sideB: 1; edgeColor: root.dieMarkColor }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.landed
        z: 10
        textFormat: Text.PlainText
        text: String(root.resultValue)
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Math.min(root.width, root.height) * 0.22
        font.bold: true
    }
}
