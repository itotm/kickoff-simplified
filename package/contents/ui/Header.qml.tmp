/*
    SPDX-FileCopyrightText: 2014 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2020 Carl Schwan <carl@carlschwan.eu>
    SPDX-FileCopyrightText: 2021 Mikel Johnson <mikel5764@gmail.com>
    SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components as KirigamiComponents
import org.kde.coreaddons as KCoreAddons
import org.kde.kcmutils as KCM
import org.kde.config as KConfig
import org.kde.plasma.plasmoid

PlasmaExtras.PlasmoidHeading {
    id: root

    readonly property string searchText: kickoff.searchField ? kickoff.searchField.text : ""
    property Item avatar: avatar
    // Compatibility aliases (pin/configure are removed from the UI).
    property Item configureButton: null
    property Item pinButton: null
    property real preferredNameAndIconWidth: 0

    // Standard KDE compact header size.
    readonly property int _avatarSize: Kirigami.Units.iconSizes.smallMedium

    contentHeight: _avatarSize + Kirigami.Units.smallSpacing * 2

    leftPadding: kickoff.backgroundMetrics.leftPadding
    rightPadding: kickoff.backgroundMetrics.rightPadding
    topPadding: 0
    bottomPadding: 0

    KCoreAddons.KUser {
        id: kuser
    }

    spacing: kickoff.backgroundMetrics.spacing

    contentItem: RowLayout {
        id: rowLayout
        spacing: root.spacing
        LayoutMirroring.enabled: kickoff.sideBarOnRight

        KirigamiComponents.AvatarButton {
            id: avatar
            visible: KConfig.KAuthorized.authorizeControlModule("kcm_users")

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root._avatarSize
            Layout.preferredHeight: root._avatarSize

            text: i18nc("@action:button icon-only, for tooltip/Accessible", "Open user settings") // qmllint disable unqualified
            name: kuser.fullName
            cache: false
            source: kuser.faceIconUrl

            Keys.onTabPressed: event => {
                (kickoff.firstCentralPane || nextItemInFocusChain()).forceActiveFocus(Qt.TabFocusReason)
            }
            Keys.onDownPressed: event => {
                if (kickoff.sideBar) {
                    kickoff.sideBar.forceActiveFocus(Qt.TabFocusReason)
                } else if (kickoff.contentArea) {
                    kickoff.contentArea.forceActiveFocus(Qt.TabFocusReason)
                }
            }

            onClicked: KCM.KCMLauncher.openSystemSettings("kcm_users")
        }

        MouseArea {
            id: nameAndInfoMouseArea
            hoverEnabled: true

            Layout.fillHeight: true
            Layout.fillWidth: true

            Kirigami.Heading {
                id: nameLabel
                anchors.fill: parent
                opacity: parent.containsMouse ? 0 : 1
                color: Kirigami.Theme.textColor
                level: 4
                text: kuser.fullName
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: kickoff.paneSwap ? Text.AlignRight : Text.AlignLeft
                verticalAlignment: Text.AlignVCenter

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Kirigami.Heading {
                id: infoLabel
                anchors.fill: parent
                level: 5
                opacity: parent.containsMouse ? 1 : 0
                color: Kirigami.Theme.textColor
                text: kuser.os !== "" ? `${kuser.loginName}@${kuser.host} (${kuser.os})` : `${kuser.loginName}@${kuser.host}`
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: kickoff.paneSwap ? Text.AlignRight : Text.AlignLeft
                verticalAlignment: Text.AlignVCenter

                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            PC3.ToolTip.text: infoLabel.text
            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            PC3.ToolTip.visible: infoLabel.truncated && containsMouse
        }
    }
}
