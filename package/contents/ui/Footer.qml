/*
 *    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
 *    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
 *
 *    SPDX-License-Identifier: GPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmaExtras.PlasmoidHeading {
    id: root

    readonly property alias searchField: searchField
    readonly property alias leaveButtons: leaveButtons
    // Kept for backwards compatibility with callers; no tabs any more.
    property real preferredTabBarWidth: 0

    contentWidth: searchField.implicitWidth + spacing + leaveButtons.implicitWidth
    contentHeight: Math.max(searchField.implicitHeight, leaveButtons.implicitHeight)

    leftPadding: kickoff.backgroundMetrics.leftPadding
    rightPadding: kickoff.backgroundMetrics.rightPadding
    topPadding: Kirigami.Units.smallSpacing * 2
    bottomPadding: Kirigami.Units.smallSpacing * 2

    topInset: 0
    leftInset: 0
    rightInset: 0
    bottomInset: 0

    spacing: kickoff.backgroundMetrics.spacing
    position: PC3.ToolBar.Footer

    PlasmaExtras.SearchField {
        id: searchField

        focus: true

        // Keep a fixed, compact width (standard KDE search size, matching the screenshot).
        width: Kirigami.Units.gridUnit * 12
        implicitWidth: width

        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }

        Binding {
            target: kickoff
            property: "searchField"
            value: searchField
            restoreMode: Binding.RestoreNone
        }
        Connections {
            target: kickoff
            function onExpandedChanged() {
                if (!kickoff.expanded) {
                    searchField.clear()
                } else {
                    searchField.forceActiveFocus(Qt.ShortcutFocusReason)
                }
            }
        }

        onTextEdited: {
            searchField.forceActiveFocus(Qt.ShortcutFocusReason)
        }

        Keys.priority: Keys.AfterItem
        Keys.forwardTo: kickoff.contentArea !== null ? kickoff.contentArea.view : []

        Keys.onUpPressed: event => {
            if (kickoff.contentArea) {
                kickoff.contentArea.forceActiveFocus(Qt.BacktabFocusReason)
            }
        }
        Keys.onTabPressed: event => {
            leaveButtons.nextItemInFocusChain().forceActiveFocus(Qt.TabFocusReason)
        }
        Keys.onBacktabPressed: event => {
            (kickoff.lastCentralPane || kickoff.firstHeaderItem).forceActiveFocus(Qt.BacktabFocusReason)
        }
    }

    LeaveButtons {
        id: leaveButtons

        anchors {
            top: parent.top
            right: parent.right
            bottom: parent.bottom
        }

        maximumWidth: root.availableWidth

        Keys.onUpPressed: event => {
            kickoff.lastCentralPane.forceActiveFocus(Qt.BacktabFocusReason);
        }
    }

    Behavior on height {
        enabled: kickoff.expanded
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.InQuad
        }
    }
}
