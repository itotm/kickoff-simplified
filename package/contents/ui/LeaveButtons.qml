/*
    SPDX-FileCopyrightText: 2020 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Kai Uwe Broulik <kde@broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PC3
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.plasmoid

RowLayout {
    id: root

    required property real maximumWidth

    // All session/power actions live inside the overflow "Session" menu.
    readonly property var __layout: ({
        allActionsArePrimary: false,
        collapseActionButtons: true,
        collapseOverflowMenuButton: false,
        overflowMenuButtonIsVisible: true,
    })

    spacing: kickoff.backgroundMetrics.spacing

    // Fade-to-black applies only to these destructive actions.
    readonly property var _fadeFavoriteIds: ["shutdown", "reboot", "logout"]

    // Starts the fade overlay first (so it's visible before any system confirm
    // dialog steals focus), then triggers the action on the next frame.
    function triggerWithFade(filteredModel, index, favoriteId) {
        const shouldFade = Plasmoid.configuration.fadeOnExit && _fadeFavoriteIds.includes(String(favoriteId))
        if (shouldFade) {
            startFade()
        }
        deferredTrigger.filteredModel = filteredModel
        deferredTrigger.index = index
        deferredTrigger.start()
    }

    Timer {
        id: deferredTrigger
        interval: 16 // one frame: let the overlay paint before the action may open a modal dialog
        repeat: false
        property var filteredModel: null
        property int index: -1
        onTriggered: {
            if (filteredModel && index >= 0) {
                filteredModel.trigger(index)
            }
            if (kickoff.hideOnWindowDeactivate) {
                kickoff.expanded = false
            }
        }
    }

    function startFade() {
        fadeRect.opacity = 0
        fadeOverlay.visible = true
        fadeOverlay.requestActivate()
        fadeAnimation.restart()
    }

    function stopFade() {
        fadeAnimation.stop()
        fadeRect.opacity = 0
        fadeOverlay.visible = false
    }

    Window {
        id: fadeOverlay
        visible: false
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.BypassWindowManagerHint | Qt.WindowStaysOnTopHint
        x: Screen.virtualX
        y: Screen.virtualY
        width: Screen.desktopAvailableWidth
        height: Screen.desktopAvailableHeight

        Rectangle {
            id: fadeRect
            anchors.fill: parent
            color: "black"
            opacity: 0
            focus: true
            Keys.onEscapePressed: root.stopFade()
        }

        // MouseArea also lets you click anywhere to cancel during testing.
        MouseArea {
            anchors.fill: parent
            onClicked: root.stopFade()
        }
    }

    NumberAnimation {
        id: fadeAnimation
        target: fadeRect
        property: "opacity"
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.Linear
    }

    Kicker.SystemModel {
        id: systemModel
        favoritesModel: kickoff.rootModel.systemFavoritesModel
    }

    component FilteredModel : KItemModels.KSortFilterProxyModel {
        sourceModel: systemModel

        function systemFavoritesContainsRow(sourceRow, sourceParent) {
            const FavoriteIdRole = sourceModel.KItemModels.KRoleNames.role("favoriteId");
            const favoriteId = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), FavoriteIdRole);
            return String(Plasmoid.configuration.systemFavorites).includes(favoriteId);
        }

        function trigger(index) {
            const sourceIndex = mapToSource(this.index(index, 0));
            systemModel.trigger(sourceIndex.row, "", null);
        }

        Component.onCompleted: {
            Plasmoid.configuration.valueChanged.connect((key, value) => {
                if (key === "systemFavorites") {
                    invalidateFilter();
                }
            });
        }
    }

    FilteredModel {
        id: filteredButtonsModel
        filterRowCallback: (sourceRow, sourceParent) =>
            systemFavoritesContainsRow(sourceRow, sourceParent)
    }

    FilteredModel {
        id: filteredMenuItemsModel
        filterRowCallback: root.__layout.collapseActionButtons
            ? null /*i.e. keep all rows*/
            : (sourceRow, sourceParent) => !systemFavoritesContainsRow(sourceRow, sourceParent)
    }

    Item {
        Layout.fillWidth: root.__layout.allActionsArePrimary
    }

    RowLayout {
        id: buttonsRepeaterRow
        // HACK Can't use `visible` property, as the layout needs to be
        // visible to be able to update its implicit size, which in turn is
        // be used to set collapseActionButtons.
        enabled: !root.__layout.collapseActionButtons
        opacity: !root.__layout.collapseActionButtons ? 1 : 0
        spacing: parent.spacing
        Repeater {
            id: buttonRepeater

            model: filteredButtonsModel
            delegate: PC3.ToolButton {
                required property int index
                required property var model

                text: model.display
                icon.name: model.decoration
                onClicked: {
                    root.triggerWithFade(filteredButtonsModel, index, model.favoriteId)
                }
                display: PC3.AbstractButton.IconOnly;
                Layout.rightMargin: model.favoriteId === "switch-user" && root.__layout.allActionsArePrimary ? Kirigami.Units.gridUnit : undefined

                PC3.ToolTip.text: text
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                PC3.ToolTip.visible: display === PC3.AbstractButton.IconOnly && hovered

                Keys.onTabPressed: event => {
                    if (index === buttonRepeater.count - 1 && !root.__layout.overflowMenuButtonIsVisible) {
                        kickoff.firstHeaderItem.forceActiveFocus(Qt.TabFocusReason)
                    } else {
                        event.accepted = false
                    }
                }
                Keys.onLeftPressed: event => {
                    if (Application.layoutDirection === Qt.LeftToRight) {
                        nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                    } else if (index < buttonRepeater.count - 1 || root.__layout.overflowMenuButtonIsVisible) {
                        nextItemInFocusChain().forceActiveFocus(Qt.TabFocusReason)
                    }
                }
                Keys.onRightPressed: event => {
                    if (Application.layoutDirection === Qt.RightToLeft) {
                        nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
                    } else if (index < buttonRepeater.count - 1 || root.__layout.overflowMenuButtonIsVisible) {
                        nextItemInFocusChain().forceActiveFocus(Qt.TabFocusReason)
                    }
                }
                Keys.onEnterPressed: clicked()
                Keys.onReturnPressed: clicked()
            }
        }
    }

    Item {
        Layout.fillWidth: !root.__layout.allActionsArePrimary
    }

    // Just like Kirigami.ActionToolBar, it takes two actual instances of a
    // button with different display modes to calculate the layout properly
    // without binding loops.
    component OverflowMenuButton : PC3.ToolButton {
        Accessible.role: Accessible.ButtonMenu
        Layout.fillHeight: true
        icon.width: Kirigami.Units.iconSizes.smallMedium
        icon.height: Kirigami.Units.iconSizes.smallMedium
        icon.name: "system-log-out"
        text: i18nc("@title:menu menubutton", "Session") // qmllint disable unqualified
        // Make it look pressed while the menu is open
        down: contextMenu.status === PlasmaExtras.Menu.Open || pressed
        Keys.onTabPressed: event => {
            kickoff.firstHeaderItem.forceActiveFocus(Qt.TabFocusReason);
        }
        Keys.onLeftPressed: event => {
            if (!mirrored) {
                nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
            }
        }
        Keys.onRightPressed: event => {
            if (mirrored) {
                nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
            }
        }
        onPressed: {
            contextMenu.visualParent = this;
            contextMenu.openRelative();
        }
    }

    OverflowMenuButton {
        id: overflowMenuButtonTextBesideIcon
        display: PC3.AbstractButton.TextBesideIcon
        visible: root.__layout.overflowMenuButtonIsVisible && !root.__layout.collapseOverflowMenuButton
    }

    OverflowMenuButton {
        id: overflowMenuButtonIconOnly
        display: PC3.AbstractButton.IconOnly
        visible: root.__layout.overflowMenuButtonIsVisible && root.__layout.collapseOverflowMenuButton

        PC3.ToolTip.text: text
        PC3.ToolTip.visible: hovered || activeFocus
        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
    }

    Instantiator {
        model: filteredMenuItemsModel
        delegate: PlasmaExtras.MenuItem {
            required property int index
            required property var model

            text: model.display
            icon: model.decoration
            onClicked: {
                root.triggerWithFade(filteredMenuItemsModel, index, model.favoriteId)
            }
        }
        onObjectAdded: (index, object) => contextMenu.addMenuItem(object)
        onObjectRemoved: (index, object) => contextMenu.removeMenuItem(object)
    }

    PlasmaExtras.Menu {
        id: contextMenu

        PlasmaExtras.MenuItem {
            id: testFadeMenuItem
            text: i18nc("@action:inmenu Trigger fade-to-black overlay for testing", "Test Fade") // qmllint disable unqualified
            icon: "view-presentation"
            onClicked: root.startFade()
        }

        placement: {
            switch (Plasmoid.location) {
            case PlasmaCore.Types.LeftEdge:
            case PlasmaCore.Types.RightEdge:
            case PlasmaCore.Types.TopEdge:
                return PlasmaExtras.Menu.BottomPosedRightAlignedPopup;
            case PlasmaCore.Types.BottomEdge:
            default:
                return PlasmaExtras.Menu.TopPosedRightAlignedPopup;
            }
        }
    }
}
