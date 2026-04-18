/*
    SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2012 Gregor Taetzner <gregor@freenet.de>
    SPDX-FileCopyrightText: 2012 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2013 2014 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras as PlasmaExtras

EmptyPage {
    id: root

    // kickoff is Kickoff.qml
    leftPadding: -kickoff.backgroundMetrics.leftPadding
    rightPadding: -kickoff.backgroundMetrics.rightPadding
    topPadding: 0
    bottomPadding: -kickoff.backgroundMetrics.bottomPadding
    readonly property var appletInterface: kickoff

    // Minimum content-area width = same as search field (12 grid units).
    readonly property real _minContentWidth: Kirigami.Units.gridUnit * 12

    Layout.minimumWidth: normalPage.preferredSideBarWidth + _minContentWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredWidth: Plasmoid.configuration.customWidth > 0
        ? Math.max(Layout.minimumWidth, Plasmoid.configuration.customWidth)
        : Math.max(implicitWidth, width)
    Layout.preferredHeight: Plasmoid.configuration.customHeight > 0
        ? Math.max(Layout.minimumHeight, Plasmoid.configuration.customHeight)
        : Math.max(implicitHeight, height)

    property alias normalPage: normalPage
    property bool blockingHoverFocus: true
    property var interceptedPosition: null

    /* NOTE: Important things to know about keyboard input handling:
     *
     * - Key events are passed up to parent items until the end is reached.
     * Be mindful of this when using `Keys.forwardTo`.
     *
     * - Keys defaults to BeforeItem while KeyNavigation defaults to AfterItem.
     *
     * - When Keys and KeyNavigation are using the same priority, it seems like
     * the one declared first in the QML file gets priority over the other.
     *
     * - Except for Keys.onPressed, all Keys.on*Pressed signals automatically
     * set `event.accepted = true`.
     *
     * - If you do `item.forceActiveFocus()` and `item` is a focus scope, the
     * children of `item` won't necessarily get focus. It seems like
     * `forceActiveFocus()` is better for forcing a specific thing to be focused
     * while KeyNavigation is better at passing focus down to children of the
     * thing you want to focus when dealing with focus scopes.
     *
     * - KeyNavigation uses BacktabFocusReason (TabFocusReason if mirrored) for left,
     * TabFocusReason (BacktabFocusReason if mirrored) for right,
     * BacktabFocusReason for up and TabFocusReason for down.
     *
     * - KeyNavigation does not seem to respect dynamic changes to focus chain
     * rules in the reverse direction, which can lead to confusing results.
     * It is therefore safer to use Keys for items whose position in the Tab
     * order must be changed on demand. (Tested with Qt 5.15.8 on X11.)
     */

    header: Header {
        id: header
        preferredNameAndIconWidth: normalPage.preferredSideBarWidth
        Binding {
            target: kickoff
            property: "header"
            value: header
            restoreMode: Binding.RestoreBinding
        }
    }

    contentItem: VerticalStackView {
        id: contentItemStackView
        focus: true
        movementTransitionsEnabled: true
        // Not using a component to prevent it from being destroyed
        initialItem: NormalPage {
            id: normalPage
            objectName: "normalPage"
        }

        Connections {
            target: kickoff
            function onExpandedChanged() {
                if (!kickoff.expanded) {
                    root.blockingHoverFocus = true
                    root.interceptedPosition = null
                }
            }
        }

        Connections {
            target: blockHoverFocusHandler
            enabled: blockHoverFocusHandler.enabled && !root.interceptedPosition
            function onPointChanged() {
                root.interceptedPosition = blockHoverFocusHandler.point.position
            }
        }

        Connections {
            target: blockHoverFocusHandler
            enabled: blockHoverFocusHandler.enabled && root.interceptedPosition && root.blockingHoverFocus
            function onPointChanged() {
                if (blockHoverFocusHandler.point.position === root.interceptedPosition) {
                    return;
                }
                root.blockingHoverFocus = false
            }
        }

        HoverHandler {
            id: blockHoverFocusHandler
            enabled: !contentItemStackView.busy && (!root.interceptedPosition || root.blockingHoverFocus)
        }

        Keys.priority: Keys.AfterItem
        // This is here rather than root because events are implicitly forwarded
        // to parent items. Don't want to send multiple events to searchField.
        Keys.forwardTo: kickoff.searchField
    }

    Component.onCompleted: {
        rootModel.refresh();
    }

    // ===== ALT + drag to resize the whole popup =====
    component EdgeResizer : Item {
        id: edge
        property int axis: Qt.Horizontal // Qt.Horizontal resizes width, Qt.Vertical resizes height
        property int sign: 1 // +1: drag in axis direction grows; -1: inverted (e.g. left/top edges)
        z: -1
        // Only become event-aware when Alt is held, so we don't steal hover/tooltip events from the footer/header.
        enabled: altMonitor.altHeld
        opacity: 0
        property real _startSize: 0

        DragHandler {
            id: dragHandler
            target: null
            acceptedModifiers: Qt.AltModifier
            xAxis.enabled: edge.axis === Qt.Horizontal
            yAxis.enabled: edge.axis === Qt.Vertical
            cursorShape: edge.axis === Qt.Horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
            onActiveChanged: {
                if (active) {
                    edge._startSize = edge.axis === Qt.Horizontal ? root.width : root.height
                } else {
                    if (edge.axis === Qt.Horizontal) {
                        Plasmoid.configuration.customWidth = Math.max(root.Layout.minimumWidth, root.width)
                    } else {
                        Plasmoid.configuration.customHeight = Math.max(root.Layout.minimumHeight, root.height)
                    }
                }
            }
            onTranslationChanged: {
                if (!active) return
                const delta = edge.axis === Qt.Horizontal
                    ? translation.x * edge.sign
                    : translation.y * edge.sign
                if (edge.axis === Qt.Horizontal) {
                    Plasmoid.configuration.customWidth = Math.max(root.Layout.minimumWidth, edge._startSize + delta)
                } else {
                    Plasmoid.configuration.customHeight = Math.max(root.Layout.minimumHeight, edge._startSize + delta)
                }
            }
        }
        HoverHandler {
            acceptedModifiers: Qt.AltModifier
            cursorShape: edge.axis === Qt.Horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
        }
    }

    EdgeResizer {
        axis: Qt.Horizontal; sign: 1
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 6
    }
    EdgeResizer {
        axis: Qt.Horizontal; sign: -1
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 6
    }
    EdgeResizer {
        axis: Qt.Vertical; sign: 1
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 6
    }
    EdgeResizer {
        axis: Qt.Vertical; sign: -1
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 6
    }

    // Tracks whether Alt is currently held, to enable the EdgeResizers only then
    // (otherwise they'd intercept hover/cursor events from the footer/header).
    Item {
        id: altMonitor
        anchors.fill: parent
        z: -2
        property bool altHeld: false
        focus: false
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Alt) altHeld = true
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt) altHeld = false
        }
        // Fallback: poll modifier state via a HoverHandler (passive, doesn't grab).
        HoverHandler {
            acceptedDevices: PointerDevice.AllDevices
            onPointChanged: altMonitor.altHeld = (point.modifiers & Qt.AltModifier) !== 0
        }
    }
}
