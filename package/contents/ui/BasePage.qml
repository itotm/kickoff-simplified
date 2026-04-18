/*
    SPDX-FileCopyrightText: 2011 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2012 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2015-2018 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.ksvg as KSvg
import org.kde.plasma.plasmoid
import org.kde.plasma.workspace.trianglemousefilter

FocusScope {
    id: root

    property real preferredSideBarWidth: implicitSideBarWidth
    property real preferredSideBarHeight: implicitSideBarHeight

    property alias sideBarComponent: sideBarLoader.sourceComponent
    property alias sideBarItem: sideBarLoader.item
    property alias contentAreaComponent: contentAreaLoader.sourceComponent
    property alias contentAreaItem: contentAreaLoader.item

    property alias implicitSideBarWidth: sideBarLoader.implicitWidth
    property alias implicitSideBarHeight: sideBarLoader.implicitHeight

    implicitWidth: preferredSideBarWidth + separator.implicitWidth + contentAreaLoader.implicitWidth
    implicitHeight: Math.max(preferredSideBarHeight, contentAreaLoader.implicitHeight)

    TriangleMouseFilter {
        id: sideBarFilter
        active: Plasmoid.configuration.switchCategoryOnHover
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }
        LayoutMirroring.enabled: kickoff.sideBarOnRight
        implicitWidth: root.preferredSideBarWidth
        implicitHeight: root.preferredSideBarHeight
        edge: kickoff.sideBarOnRight ? Qt.LeftEdge : Qt.RightEdge
        blockFirstEnter: true
        Loader {
            id: sideBarLoader
            anchors.fill: parent
            // When positioned after the content area, Tab should go to the start of the footer focus chain
            Keys.onTabPressed: event => {
                (kickoff.paneSwap ? kickoff.footer.nextItemInFocusChain() : contentAreaLoader)
                    .forceActiveFocus(Qt.TabFocusReason);
            }
            Keys.onBacktabPressed: event => {
                (kickoff.paneSwap ? contentAreaLoader : kickoff.header.avatar)
                    .forceActiveFocus(Qt.BacktabFocusReason);
            }
            Keys.onLeftPressed: event => {
                if (kickoff.sideBarOnRight) {
                    contentAreaLoader.forceActiveFocus();
                }
            }
            Keys.onRightPressed: event => {
                if (!kickoff.sideBarOnRight) {
                    contentAreaLoader.forceActiveFocus();
                }
            }
            Keys.onUpPressed: event => {
                kickoff.header.nextItemInFocusChain()
                    .forceActiveFocus(Qt.BacktabFocusReason);
            }
            Keys.onDownPressed: event => {
                (kickoff.paneSwap ? kickoff.footer.leaveButtons.nextItemInFocusChain() : kickoff.footer.searchField)
                    .forceActiveFocus(Qt.TabFocusReason);
            }
        }
    }
    KSvg.SvgItem {
        id: separator
        anchors {
            top: parent.top
            left: sideBarFilter.right
            bottom: parent.bottom
        }
        LayoutMirroring.enabled: kickoff.sideBarOnRight
        implicitWidth: naturalSize.width
        implicitHeight: implicitWidth
        elementId: "vertical-line"
        svg: KickoffSingleton.lineSvg

        // ALT + drag on the separator to resize the sidebar/content split.
        Item {
            id: sideBarResizer
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: 8
            height: parent.height
            z: 1000
            property real _startWidth: 0

            DragHandler {
                target: null
                acceptedModifiers: Qt.AltModifier
                xAxis.enabled: true
                yAxis.enabled: false
                cursorShape: Qt.SizeHorCursor
                onActiveChanged: {
                    if (active) {
                        sideBarResizer._startWidth = root.preferredSideBarWidth
                    } else {
                        Plasmoid.configuration.customSideBarWidth = Math.max(
                            root.implicitSideBarWidth, root.preferredSideBarWidth)
                    }
                }
                onTranslationChanged: {
                    if (!active) return
                    const sign = kickoff.sideBarOnRight ? -1 : 1
                    const minW = Math.max(8, root.implicitSideBarWidth * 0.5)
                    Plasmoid.configuration.customSideBarWidth = Math.max(
                        minW, sideBarResizer._startWidth + sign * translation.x)
                }
            }
            HoverHandler {
                acceptedModifiers: Qt.AltModifier
                cursorShape: Qt.SizeHorCursor
            }
        }
    }
    Loader {
        id: contentAreaLoader
        focus: true
        anchors {
            top: parent.top
            left: separator.right
            right: parent.right
            bottom: parent.bottom
        }
        LayoutMirroring.enabled: kickoff.sideBarOnRight
        // When positioned after the sidebar, Tab should go to the start of the footer focus chain
        Keys.onTabPressed: event => {
            (kickoff.paneSwap ? sideBarLoader : kickoff.footer.nextItemInFocusChain())
                .forceActiveFocus(Qt.TabFocusReason)
        }
        Keys.onBacktabPressed: event => {
            (kickoff.paneSwap ? kickoff.header.avatar : sideBarLoader)
                .forceActiveFocus(Qt.BacktabFocusReason)
        }
        Keys.onLeftPressed: event => {
            if (!kickoff.sideBarOnRight) {
                sideBarLoader.forceActiveFocus();
            }
        }
        Keys.onRightPressed: event => {
            if (kickoff.sideBarOnRight) {
                sideBarLoader.forceActiveFocus();
            }
        }
        Keys.onUpPressed: event => {
            kickoff.searchField.forceActiveFocus(Qt.BacktabFocusReason);
        }
        Keys.onDownPressed: event => {
            (kickoff.paneSwap ? kickoff.footer.searchField : kickoff.footer.leaveButtons.nextItemInFocusChain())
                .forceActiveFocus(Qt.TabFocusReason)
        }
    }
}
