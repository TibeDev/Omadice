import QtQuick
import QtQuick3D
import qs.Commons

Model {
    id: root

    property string axis: "x"
    property int sideA: -1
    property int sideB: -1
    property var edgeColor: Color.foreground

    source: "#Cube"
    position: axis === "x" ? Qt.vector3d(0, sideA * 50, sideB * 50)
        : axis === "y" ? Qt.vector3d(sideA * 50, 0, sideB * 50)
        : Qt.vector3d(sideA * 50, sideB * 50, 0)
    scale: axis === "x" ? Qt.vector3d(1, 0.01, 0.01)
        : axis === "y" ? Qt.vector3d(0.01, 1, 0.01)
        : Qt.vector3d(0.01, 0.01, 1)
    materials: PrincipledMaterial {
        baseColor: root.edgeColor
        lighting: PrincipledMaterial.NoLighting
    }
}
