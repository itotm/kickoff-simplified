/*
SPDX-FileCopyrightText: 2013 David Edmundson <davidedmundson@kde.org>
SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
SPDX-FileCopyrightText: 2022 Nate Graham <nate@kde.org>
SPDX-FileCopyrightText: 2022 ivan tkachenko <me@ratijas.tk>

SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.iconthemes as KIconThemes
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.config as KConfig
import org.kde.plasma.plasmoid

import "code/tools.js" as Tools

KCM.SimpleKCM {
    id: root

    property string cfg_menuLabel: menuLabel.text
    property string cfg_icon: Plasmoid.configuration.icon
    property alias cfg_appNameFormat: appNameFormat.currentIndex
    property bool cfg_paneSwap: Plasmoid.configuration.paneSwap
    property int cfg_favoritesDisplay: Plasmoid.configuration.favoritesDisplay
    property int cfg_applicationsDisplay: Plasmoid.configuration.applicationsDisplay
    property alias cfg_alphaSort: alphaSort.checked
    property var cfg_systemFavorites: Plasmoid.configuration.systemFavorites
    property alias cfg_compactMode: compactModeCheckbox.checked
    property alias cfg_switchCategoryOnHover: switchCategoryOnHoverCheckbox.checked
    property alias cfg_fadeOnExit: fadeOnExitCheckbox.checked
    property alias cfg_showLockScreen: lockScreenCb.checked
    property alias cfg_showLogout: logoutCb.checked
    property alias cfg_showSaveSession: saveSessionCb.checked
    property alias cfg_showSwitchUser: switchUserCb.checked
    property alias cfg_showSuspend: sleepCb.checked
    property alias cfg_showHibernate: hibernateCb.checked
    property alias cfg_showReboot: restartCb.checked
    property alias cfg_showShutdown: shutdownCb.checked

    // Pass-through properties for kcfg entries that have no UI here. They exist
    // only so the Plasma config dialog can set/read them without emitting
    // "ConfigGeneral does not have a property called cfg_<x>" warnings.
    property var cfg_favorites
    property var cfg_systemApplications
    property bool cfg_favoritesPortedToKAstats
    property int cfg_customWidth
    property int cfg_customHeight
    property int cfg_customSideBarWidth

    // Default-value placeholders. Plasma also pushes a `cfg_<name>Default`
    // counterpart for every entry; declare them so they are silently absorbed.
    property string cfg_menuLabelDefault
    property string cfg_iconDefault
    property int cfg_appNameFormatDefault
    property var cfg_favoritesDefault
    property var cfg_systemFavoritesDefault
    property bool cfg_favoritesPortedToKAstatsDefault
    property var cfg_systemApplicationsDefault
    property bool cfg_paneSwapDefault
    property int cfg_favoritesDisplayDefault
    property int cfg_applicationsDisplayDefault
    property bool cfg_alphaSortDefault
    property bool cfg_compactModeDefault
    property bool cfg_switchCategoryOnHoverDefault
    property int cfg_customWidthDefault
    property int cfg_customHeightDefault
    property int cfg_customSideBarWidthDefault
    property bool cfg_fadeOnExitDefault
    property bool cfg_showLockScreenDefault
    property bool cfg_showLogoutDefault
    property bool cfg_showSaveSessionDefault
    property bool cfg_showSwitchUserDefault
    property bool cfg_showSuspendDefault
    property bool cfg_showHibernateDefault
    property bool cfg_showRebootDefault
    property bool cfg_showShutdownDefault

    Kirigami.FormLayout {
        QQC2.Button {
            id: iconButton

            Kirigami.FormData.label: i18nc("@label prefix for icon-only button", "Icon:") // qmllint disable unqualified

            implicitWidth: previewFrame.width + Kirigami.Units.smallSpacing * 2
            implicitHeight: previewFrame.height + Kirigami.Units.smallSpacing * 2
            hoverEnabled: true

            Accessible.name: i18nc("@action:button", "Change Application Launcher's icon") // qmllint disable unqualified
            Accessible.description: i18nc("@info:whatsthis", "Current icon is %1. Click to open menu to change the current icon or reset to the default icon.", root.cfg_icon) // qmllint disable unqualified
            Accessible.role: Accessible.ButtonMenu

            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            QQC2.ToolTip.text: i18nc("@info:tooltip", "Icon name is \"%1\"", root.cfg_icon) // qmllint disable unqualified
            QQC2.ToolTip.visible: iconButton.hovered && root.cfg_icon.length > 0

            KIconThemes.IconDialog {
                id: iconDialog
                onAccepted: {
                    root.cfg_icon = iconName || Tools.defaultIconName;
                }
            }

            onPressed: iconMenu.opened ? iconMenu.close() : iconMenu.open()

            KSvg.FrameSvgItem {
                id: previewFrame
                anchors.centerIn: parent
                imagePath: Plasmoid.formFactor === PlasmaCore.Types.Vertical || Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                    ? "widgets/panel-background" : "widgets/background"
                width: Kirigami.Units.iconSizes.large + fixedMargins.left + fixedMargins.right
                height: Kirigami.Units.iconSizes.large + fixedMargins.top + fixedMargins.bottom

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.large
                    height: width
                    source: Tools.iconOrDefault(Plasmoid.formFactor, root.cfg_icon)
                }
            }

            QQC2.Menu {
                id: iconMenu

                // Appear below the button
                y: parent.height

                QQC2.MenuItem {
                    text: i18nc("@item:inmenu Open icon chooser dialog", "Choose…") // qmllint disable unqualified
                    icon.name: "document-open-folder"
                    Accessible.description: i18nc("@info:whatsthis", "Choose an icon for Application Launcher") // qmllint disable unqualified
                    onClicked: iconDialog.open()
                }
                QQC2.MenuItem {
                    text: i18nc("@item:inmenu Reset icon to default", "Reset to default icon") // qmllint disable unqualified
                    icon.name: "edit-clear"
                    enabled: root.cfg_icon !== Tools.defaultIconName
                    onClicked: root.cfg_icon = Tools.defaultIconName
                }
                QQC2.MenuItem {
                    text: i18nc("@action:inmenu", "Remove icon") // qmllint disable unqualified
                    icon.name: "delete"
                    enabled: root.cfg_icon !== "" && menuLabel.text && Plasmoid.formFactor !== PlasmaCore.Types.Vertical
                    onClicked: root.cfg_icon = ""
                }
            }
        }

        Kirigami.ActionTextField {
            id: menuLabel
            enabled: Plasmoid.formFactor !== PlasmaCore.Types.Vertical
            Kirigami.FormData.label: i18nc("@label:textbox", "Text label:") // qmllint disable unqualified
            text: Plasmoid.configuration.menuLabel
            placeholderText: i18nc("@info:placeholder", "Type here to add a text label") // qmllint disable unqualified
            onTextEdited: {
                root.cfg_menuLabel = menuLabel.text

                // This is to make sure that we always have a icon if there is no text.
                // If the user remove the icon and remove the text, without this, we'll have no icon and no text.
                // This is to force the icon to be there.
                if (!menuLabel.text)
                {
                    root.cfg_icon = root.cfg_icon || Tools.defaultIconName
                }
            }
            rightActions: QQC2.Action {
                icon.name: "edit-clear"
                enabled: menuLabel.text !== ""
                text: i18nc("@action:button", "Reset menu label") // qmllint disable unqualified
                onTriggered: {
                    menuLabel.clear()
                    root.cfg_menuLabel = ""
                    root.cfg_icon = root.cfg_icon || Tools.defaultIconName
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 25
            visible: Plasmoid.formFactor === PlasmaCore.Types.Vertical
            text: i18nc("@info", "A text label cannot be set when the Panel is vertical.") // qmllint disable unqualified
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: appNameFormat

            Kirigami.FormData.label: i18nc("@label:listbox", "Show applications as:") // qmllint disable unqualified

            model: [i18nc("@item:inlistbox", "Name only"), i18nc("@item:inlistbox", "Description only"), i18nc("@item:inlistbox", "Name (Description)"), i18nc("@item:inlistbox", "Description (Name)")] // qmllint disable unqualified
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18nc("General options", "General:") // qmllint disable unqualified
            spacing: Kirigami.Units.smallSpacing
            QQC2.CheckBox {
                id: alphaSort
                text: i18nc("@option:check", "Sort applications alphabetically") // qmllint disable unqualified
            }

            Kirigami.ContextualHelpButton {
                toolTipText: i18nc("@info:whatsthis", "This doesn't affect how applications are sorted in either search results or the favorites page.") // qmllint disable unqualified
            }
        }

        QQC2.CheckBox {
            id: compactModeCheckbox
            text: i18nc("@option:check", "Use compact list item style") // qmllint disable unqualified
            checked: Kirigami.Settings.tabletMode ? true : Plasmoid.configuration.compactMode
            enabled: !Kirigami.Settings.tabletMode
        }
        QQC2.Label {
            visible: Kirigami.Settings.tabletMode
            text: i18nc("@info:usagetip under a checkbox when Touch Mode is on", "Automatically disabled when in Touch Mode") // qmllint disable unqualified
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
        }

        QQC2.CheckBox {
            id: switchCategoryOnHoverCheckbox
            text: i18nc("@option:check", "Switch sidebar categories when hovering over them") // qmllint disable unqualified
        }

        QQC2.CheckBox {
            id: fadeOnExitCheckbox
            text: i18nc("@option:check", "Show splash screen on shutdown/restart/logout") // qmllint disable unqualified
            checked: Plasmoid.configuration.fadeOnExit
        }

        QQC2.Button {
            enabled: KConfig.KAuthorized.authorizeControlModule("kcm_plasmasearch")
            icon.name: "settings-configure"
            text: i18nc("@action:button opens plasmasearch kcm", "Configure Search Plugins…") // qmllint disable unqualified
            onClicked: KCM.KCMLauncher.openSystemSettings("kcm_plasmasearch")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        GridLayout {
            Kirigami.FormData.label: i18nc("@label:group", "Leave menu actions:") // qmllint disable unqualified
            columns: 2
            columnSpacing: Kirigami.Units.gridUnit

            QQC2.CheckBox {
                id: lockScreenCb
                text: i18nc("@option:check", "Lock") // qmllint disable unqualified
            }
            QQC2.CheckBox {
                id: logoutCb
                text: i18nc("@option:check", "Log Out") // qmllint disable unqualified
            }
            QQC2.CheckBox {
                id: saveSessionCb
                text: i18nc("@option:check", "Save Session") // qmllint disable unqualified
            }
            QQC2.CheckBox {
                id: switchUserCb
                text: i18nc("@option:check", "Switch User") // qmllint disable unqualified
            }
            QQC2.CheckBox {
                id: sleepCb
                text: i18nc("@option:check", "Sleep") // qmllint disable unqualified
            }
            QQC2.CheckBox {
                id: hibernateCb
                text: i18nc("@option:check", "Hibernate") // qmllint disable unqualified
            }
            QQC2.CheckBox {
                id: restartCb
                text: i18nc("@option:check", "Restart") // qmllint disable unqualified
            }
            QQC2.CheckBox {
                id: shutdownCb
                text: i18nc("@option:check", "Shut Down") // qmllint disable unqualified
            }
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.RadioButton {
            id: paneSwapOff
            Kirigami.FormData.label: i18nc("@label:group prefix for radio button group", "Sidebar position:") // qmllint disable unqualified
            text: mirrored ? i18nc("@option:radio sidebar position", "Right") : i18nc("option:radio sidebar position", "Left") // qmllint disable unqualified
            QQC2.ButtonGroup.group: paneSwapGroup
            property int index: 0
            checked: !Plasmoid.configuration.paneSwap
        }

        QQC2.RadioButton {
            id: paneSwapOn
            text: mirrored ? i18nc("@option:radio sidebar position", "Left") : i18nc("@option:radio sidebar position", "Right") // qmllint disable unqualified
            QQC2.ButtonGroup.group: paneSwapGroup
            property int index: 1
            checked: Plasmoid.configuration.paneSwap
        }

        QQC2.RadioButton {
            id: showFavoritesInGrid
            Kirigami.FormData.label: i18nc("@title:group prefix for radio button group", "Show favorites:") // qmllint disable unqualified
            text: i18nc("@option:radio Part of a sentence: 'Show favorites in a grid'", "In a grid") // qmllint disable unqualified
            QQC2.ButtonGroup.group: favoritesDisplayGroup
            property int index: 0
            checked: Plasmoid.configuration.favoritesDisplay === index
        }

        QQC2.RadioButton {
            id: showFavoritesInList
            text: i18nc("@option:radio Part of a sentence: 'Show favorites in a list'", "In a list") // qmllint disable unqualified
            QQC2.ButtonGroup.group: favoritesDisplayGroup
            property int index: 1
            checked: Plasmoid.configuration.favoritesDisplay === index
        }

        QQC2.RadioButton {
            id: showAppsInGrid
            Kirigami.FormData.label: i18nc("@title:group prefix for radio button group", "Show other applications:") // qmllint disable unqualified
            text: i18nc("@option:radio Part of a sentence: 'Show other applications in a grid'", "In a grid") // qmllint disable unqualified
            QQC2.ButtonGroup.group: applicationsDisplayGroup
            property int index: 0
            checked: Plasmoid.configuration.applicationsDisplay === index
        }

        QQC2.RadioButton {
            id: showAppsInList
            text: i18nc("@option:radio Part of a sentence: 'Show other applications in a list'", "In a list") // qmllint disable unqualified
            QQC2.ButtonGroup.group: applicationsDisplayGroup
            property int index: 1
            checked: Plasmoid.configuration.applicationsDisplay === index
        }
    }

    QQC2.ButtonGroup {
        id: paneSwapGroup
        onCheckedButtonChanged: {
            if (checkedButton)
            {
                root.cfg_paneSwap = checkedButton.index === 1
            }
        }
    }

    QQC2.ButtonGroup {
        id: favoritesDisplayGroup
        onCheckedButtonChanged: {
            if (checkedButton)
            {
                root.cfg_favoritesDisplay = checkedButton.index
            }
        }
    }

    QQC2.ButtonGroup {
        id: applicationsDisplayGroup
        onCheckedButtonChanged: {
            if (checkedButton)
            {
                root.cfg_applicationsDisplay = checkedButton.index
            }
        }
    }
}
