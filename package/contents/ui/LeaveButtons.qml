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
    readonly property var _fadeActionIds: ["shutdown", "reboot", "logout"]

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
    function exec(cmd)
    {
        connectSource(cmd)
    }
}

// Look up a system action by its actionId and trigger it.
// This never relies on indices — it scans systemModel at trigger time.
function triggerAction(actionId)
{
    const ActionIdRole = systemModel.KItemModels.KRoleNames.role("favoriteId");
    for (let i = 0; i < systemModel.rowCount(); i++) {
        if (String(systemModel.data(systemModel.index(i, 0), ActionIdRole)) === String(actionId))
        {
            systemModel.trigger(i, "", null);
            return;
        }
    }
}

// Starts the fade overlay, and once it's fully black spawns ksplashqml
// and triggers the requested system action.
function triggerWithFade(actionId)
{
    const id = String(actionId)
    const shouldFade = Plasmoid.configuration.fadeOnExit && _fadeActionIds.includes(id)
    deferredTrigger.actionId = id
    if (shouldFade)
    {
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
    property string actionId: ""
        onTriggered: {
            if (_fadeActionIds.includes(actionId))
            {
                // ksplashqml was already spawned in triggerWithFade and should
                // now be mapped under our overlay. Hide the overlay to reveal
                // it, then trigger the system action.
                fadeOverlay.visible = false
            }
            if (actionId !== "")
            {
                root.triggerAction(actionId)
            }
            if (kickoff.hideOnWindowDeactivate)
            {
                kickoff.expanded = false
            }
        }
    }

    function startFade()
    {
        fadeRect.opacity = 0
        fadeOverlay.visible = true
        fadeAnimation.restart()
    }

    function stopFade()
    {
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
                if (deferredTrigger.actionId !== "" && !deferredTrigger.running)
                {
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

        function isActionVisible(actionId)
        {
            switch (String(actionId)) {
            case "lock-screen": return Plasmoid.configuration.showLockScreen;
            case "logout": return Plasmoid.configuration.showLogout;
            case "save-session": return Plasmoid.configuration.showSaveSession;
            case "switch-user": return Plasmoid.configuration.showSwitchUser;
            case "suspend": return Plasmoid.configuration.showSuspend;
            case "hibernate": return Plasmoid.configuration.showHibernate;
            case "reboot": return Plasmoid.configuration.showReboot;
            case "shutdown": return Plasmoid.configuration.showShutdown;
            default: return true;
        }
    }

    function isRowVisible(sourceRow, sourceParent)
    {
        const ActionIdRole = sourceModel.KItemModels.KRoleNames.role("favoriteId");
        const actionId = sourceModel.data(sourceModel.index(sourceRow, 0, sourceParent), ActionIdRole);
        return isActionVisible(actionId);
    }

    Component.onCompleted: {
        Plasmoid.configuration.valueChanged.connect((key, value) => {
        if (key.startsWith("show") || key === "systemFavorites")
        {
            invalidateFilter();
            root.rebuildMenu();
        }
    });
}
}

FilteredModel {
    id: filteredButtonsModel
    filterRowCallback: (sourceRow, sourceParent) =>
    isRowVisible(sourceRow, sourceParent)
}

FilteredModel {
    id: filteredMenuItemsModel
    filterRowCallback: root.__layout.collapseActionButtons
    ? (sourceRow, sourceParent) => isRowVisible(sourceRow, sourceParent)
    : (sourceRow, sourceParent) => !isRowVisible(sourceRow, sourceParent)
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
                root.triggerWithFade(model.favoriteId)
            }
            display: PC3.AbstractButton.IconOnly;
            Layout.rightMargin: model.favoriteId === "switch-user" && root.__layout.allActionsArePrimary ? Kirigami.Units.gridUnit : undefined

            PC3.ToolTip.text: text
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            PC3.ToolTip.visible: display === PC3.AbstractButton.IconOnly && hovered

            Keys.onTabPressed: event => {
            if (index === buttonRepeater.count - 1 && !root.__layout.overflowMenuButtonIsVisible)
            {
                kickoff.firstHeaderItem.forceActiveFocus(Qt.TabFocusReason)
            } else {
            event.accepted = false
        }
    }
    Keys.onLeftPressed: event => {
    if (Application.layoutDirection === Qt.LeftToRight)
    {
        nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
    } else if (index < buttonRepeater.count - 1 || root.__layout.overflowMenuButtonIsVisible) {
    nextItemInFocusChain().forceActiveFocus(Qt.TabFocusReason)
}
}
Keys.onRightPressed: event => {
if (Application.layoutDirection === Qt.RightToLeft)
{
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
if (!mirrored)
{
    nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
}
}
Keys.onRightPressed: event => {
if (mirrored)
{
    nextItemInFocusChain(false).forceActiveFocus(Qt.BacktabFocusReason)
}
}
onPressed: {
    contextMenu.visualParent = this;
    root.rebuildMenu();
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

Instantiator {
    id: menuInstantiator
    model: filteredMenuItemsModel
    delegate: PlasmaExtras.MenuItem {
        required property var model

        text: model.display
        icon: model.decoration
        onClicked: root.triggerWithFade(model.favoriteId)
    }
    onObjectAdded: (index, object) => contextMenu.addMenuItem(object)
    onObjectRemoved: (index, object) => contextMenu.removeMenuItem(object)
}

// Force the Instantiator to tear down and recreate all menu items
// in the correct model order. Called only on config changes.
function rebuildMenu()
{
    menuInstantiator.model = null
    menuInstantiator.model = filteredMenuItemsModel
}
}
