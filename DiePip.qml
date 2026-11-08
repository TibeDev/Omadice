import QtQuick
import QtQuick3D
import qs.Commons

Model {
    id: root

    property string axis: "z"
    property var pipColor: Color.foreground

    source: "#Sphere"
    scale: Qt.vector3d(0.12, 0.12, 0.001)
    eulerRotation: axis === "x" ? Qt.vector3d(0, 90, 0)
        : axis === "y" ? Qt.vector3d(90, 0, 0)
        : Qt.vector3d(0, 0, 0)
    materials: PrincipledMaterial {
        baseColor: root.pipColor
        lighting: PrincipledMaterial.NoLighting
    }
}
