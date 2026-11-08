import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
    id: root

    moduleName: "tibevdb.dice"
    property bool menuOpen: false
    property int menuIndex: 0

    readonly property real throwPower: {
        var configured = Number(root.setting("throwPower", 1))
        return isFinite(configured) ? Math.max(0.5, Math.min(1.5, configured)) : 1
    }
    readonly property string diceTheme: {
        var configured = String(root.setting("diceTheme", "normal"))
        return configured === "theme" || configured === "inverted" ? configured : "normal"
    }

    function close() {
        menuOpen = false
    }

    function toggleSettings() {
        menuIndex = 0
        menuOpen = !menuOpen
    }

    function throwDice() {
        diceOverlay.throwDice()
    }

    function persistSettings(values) {
        var entry = { id: root.moduleName }
        for (var existing in root.settings)
            if (existing !== "id") entry[existing] = root.settings[existing]
        for (var key in values)
            entry[key] = values[key]

        root.settings = entry
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
            root.bar.shell.updateEntryInline(root.moduleName, entry)
    }

    function setDiceTheme(theme) {
        if (root.diceTheme !== theme)
            root.persistSettings({ diceTheme: theme })
    }

    function activateMenuItem() {
        if (menuIndex === 1) root.setDiceTheme("normal")
        else if (menuIndex === 2) root.setDiceTheme("theme")
        else if (menuIndex === 3) root.setDiceTheme("inverted")
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    DieOverlay {
        id: diceOverlay
        throwPower: root.throwPower
        diceTheme: root.diceTheme
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "⚄"
        tooltipText: "Throw dice"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.RightButton)
                root.toggleSettings()
            else if (buttonCode === Qt.LeftButton) {
                root.close()
                root.throwDice()
            }
        }
    }

    Translations {
        id: strings
        directory: Qt.resolvedUrl("i18n")
    }

    KeyboardPanel {
        id: settingsPanel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.menuOpen
        focusTarget: keyCatcher
        contentWidth: settingsPanel.fittedContentWidth(Style.space(320))
        contentHeight: settingsPanel.fittedContentHeight(settingsColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onMoveRequested: function(dx, dy) {
                if (dx !== 0 || dy === 0)
                    return
                root.menuIndex = Math.max(0, Math.min(3, root.menuIndex + (dy > 0 ? 1 : -1)))
            }
            onActivateRequested: root.activateMenuItem()

            Column {
                id: settingsColumn
                anchors.fill: parent
                spacing: Style.space(8)

                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: strings.t("dice.settings.title")
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                }

                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: strings.t("dice.settings.throwPower")
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }

                Row {
                    width: parent.width
                    spacing: Style.space(8)

                    PanelSlider {
                        id: powerSlider
                        width: parent.width - powerLabel.implicitWidth - Style.space(8)
                        bar: root.bar
                        minimum: 0.5
                        maximum: 1.5
                        step: 0.05
                        value: root.throwPower
                        onReleased: function(value) { root.persistSettings({ throwPower: value }) }
                    }

                    Text {
                        id: powerLabel
                        textFormat: Text.PlainText
                        text: Math.round((powerSlider.dragging ? powerSlider.liveValue : root.throwPower) * 100) + "%"
                        color: Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                PanelSeparator { width: parent.width }

                Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: strings.t("dice.settings.theme")
                    color: Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }

                Button {
                    width: parent.width
                    text: strings.t("dice.theme.normal")
                    leftAlign: true
                    foreground: Color.popups.text
                    selected: root.diceTheme === "normal"
                    hasCursor: root.menuIndex === 1
                    onHovered: function(hovered) { if (hovered) root.menuIndex = 1 }
                    onClicked: root.setDiceTheme("normal")
                }

                Button {
                    width: parent.width
                    text: strings.t("dice.theme.follow")
                    leftAlign: true
                    foreground: Color.popups.text
                    selected: root.diceTheme === "theme"
                    hasCursor: root.menuIndex === 2
                    onHovered: function(hovered) { if (hovered) root.menuIndex = 2 }
                    onClicked: root.setDiceTheme("theme")
                }

                Button {
                    width: parent.width
                    text: strings.t("dice.theme.inverted")
                    leftAlign: true
                    foreground: Color.popups.text
                    selected: root.diceTheme === "inverted"
                    hasCursor: root.menuIndex === 3
                    onHovered: function(hovered) { if (hovered) root.menuIndex = 3 }
                    onClicked: root.setDiceTheme("inverted")
                }
            }
        }
    }
}
