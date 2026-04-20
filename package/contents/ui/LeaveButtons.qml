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
import org.kde.plasma.plasma5support as P5Support
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

    // Spawns arbitrary commands via the Plasma executable data engine, so we
    // can launch `ksplashqml` right before the action is triggered. That paints
    // the user's configured Plasma splash over the screen while Plasma tears
    // down, bridging smoothly into Plymouth.
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
        }
        function exec(cmd) {
            connectSource(cmd)
        }
    }

    // Starts the fade overlay, and once it's fully black spawns ksplashqml
    // and triggers the requested system action.
    function triggerWithFade(filteredModel, index, favoriteId) {
        const shouldFade = Plasmoid.configuration.fadeOnExit && _fadeFavoriteIds.includes(String(favoriteId))
        deferredTrigger.filteredModel = filteredModel
        deferredTrigger.index = index
        deferredTrigger.favoriteId = String(favoriteId)
        if (shouldFade) {
            // Spawn ksplashqml up front so it has time to map underneath our
            // fade overlay during the fade animation. When the fade finishes
            // we simply hide our overlay and the splash is already on screen.
            // Detached via `setsid` so it survives the session teardown.
            executable.exec("setsid -f sh -c 'ksplashqml </dev/null >/dev/null 2>&1' </dev/null >/dev/null 2>&1 &")
            startFade()
            // deferredTrigger is started by fadeAnimation.onFinished
        } else {
            deferredTrigger.interval = 16
            deferredTrigger.start()
        }
    }

    Timer {
        id: deferredTrigger
        interval: 16
        repeat: false
        property var filteredModel: null
        property int index: -1
        property string favoriteId: ""
        onTriggered: {
            if (_fadeFavoriteIds.includes(favoriteId)) {
                // ksplashqml was already spawned in triggerWithFade and should
                // now be mapped under our overlay. Hide the overlay to reveal
                // it, then trigger the system action.
                fadeOverlay.visible = false
            }
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
        fadeAnimation.restart()
    }

    function stopFade() {
        fadeAnimation.stop()
        fadeRect.opacity = 0
        fadeOverlay.visible = false
    }

    // Plasma dialog of type OnScreenDisplay renders on the OSD layer, above
    // panels, on both X11 and Wayland (layer-shell overlay). This lets the
    // fade cover the Plasma main toolbar too.
    PlasmaCore.Dialog {
        id: fadeOverlay
        visible: false
        location: PlasmaCore.Types.Floating
        type: PlasmaCore.Dialog.OnScreenDisplay
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        outputOnly: false
        hideOnWindowDeactivate: false

        // PlasmaCore.Dialog always draws its themed frame around mainItem.
        // Oversize mainItem so the frame (plus any margins) falls well outside
        // the visible screen area on every side.
        readonly property int overscan: 128

        // Shift the whole window up-left by `overscan`, and make the content
        // `2 * overscan` larger in each dimension, so the black area still
        // covers the full screen and the theme border is never visible.
        x: -overscan
        y: -overscan

        mainItem: Item {
            implicitWidth: Screen.width + fadeOverlay.overscan * 2
            implicitHeight: Screen.height + fadeOverlay.overscan * 2

            Rectangle {
                id: fadeRect
                anchors.fill: parent
                color: "black"
                opacity: 0
                focus: fadeOverlay.visible
                Keys.onEscapePressed: root.stopFade()
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.BlankCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: root.stopFade()
            }
        }
    }

    NumberAnimation {
        id: fadeAnimation
        target: fadeRect
        property: "opacity"
        from: 0
        to: 1
        duration: 250
        easing.type: Easing.Linear
        onFinished: {
            // Only hand off once we're fully black.
            if (deferredTrigger.favoriteId !== "" && !deferredTrigger.running) {
                deferredTrigger.interval = 16
                deferredTrigger.start()
            }
        }
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
        text: i18nc("@title:menu menubutton", "Leave") // qmllint disable unqualified
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
