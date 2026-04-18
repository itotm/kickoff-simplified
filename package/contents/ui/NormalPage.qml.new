/*
 * SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import org.kde.plasma.plasmoid

EmptyPage {
    id: root
    readonly property real implicitSideBarWidth: applicationsPage.implicitSideBarWidth
    property real preferredSideBarWidth: Plasmoid.configuration.customSideBarWidth > 0
        ? Plasmoid.configuration.customSideBarWidth
        : applicationsPage.implicitSideBarWidth

    contentItem: HorizontalStackView {
        id: stackView
        focus: true
        reverseTransitions: false
        initialItem: ApplicationsPage {
            id: applicationsPage
            preferredSideBarWidth: root.preferredSideBarWidth + kickoff.backgroundMetrics.leftPadding
        }
    }

    footer: Footer {
        id: footer
        preferredTabBarWidth: root.preferredSideBarWidth
        Binding {
            target: kickoff
            property: "footer"
            value: footer
            restoreMode: Binding.RestoreBinding
        }
        Keys.onDownPressed: event => {}
    }
}
