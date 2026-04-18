/*
 * SPDX-FileCopyrightText: 2021 Noah Davis <noahadvs@gmail.com>
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Templates as T
import org.kde.plasma.private.kicker as Kicker
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras

BasePage {
    id: root

    property real flashFavorite: 0

    // Flash favorites when adding one.
    SequentialAnimation {
        id: flashFavoriteAnimation
        loops: 2
        alwaysRunToEnd: true

        NumberAnimation {
            target: root
            property: "flashFavorite"
            from: 0
            to: 1
            duration: Kirigami.Units.veryLongDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "flashFavorite"
            to: 0
            duration: Kirigami.Units.veryLongDuration
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: kickoff.rootModel.favoritesModel
        function onFavoriteAdded() : void {
            flashFavoriteAnimation.restart();
        }
    }

    sideBarComponent: KickoffListView {
        id: sideBar
        focus: true // needed for Loaders
        model: kickoff.rootModel
        isSidebar: true
        // needed otherwise app displayed at top-level will show a first character as group.
        section.property: ""
        delegate: KickoffListDelegate {
            id: sideBarDelegate
            width: view.availableWidth
            isCategoryListItem: true

            background: PlasmaExtras.Highlight {
                // I have to do this for it to actually fill the item for some reason
                anchors.fill: parent
                active: false
                hovered: sideBarDelegate.mouseArea.containsMouse || (flashFavoriteAnimation.running && sideBarDelegate.index === 0)
                visible: !Plasmoid.configuration.switchCategoryOnHover
                    && !sideBarDelegate.isSeparator && !sideBarDelegate.ListView.isCurrentItem
                    && hovered
                opacity: flashFavoriteAnimation.running && sideBarDelegate.index === 0 ? root.flashFavorite : 1
            }
        }
    }

    contentAreaComponent: VerticalStackView {
        id: stackView

        popEnter: Transition {
            NumberAnimation {
                property: "x"
                from: 0.5 * root.width
                to: 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }

        pushEnter: Transition {
            NumberAnimation {
                property: "x"
                from: 0.5 * -root.width
                to: 0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }

        readonly property string preferredFavoritesViewObjectName: Plasmoid.configuration.favoritesDisplay === 0 ? "favoritesGridView" : "favoritesListView"
        readonly property Component preferredFavoritesViewComponent: Plasmoid.configuration.favoritesDisplay === 0 ? favoritesGridViewComponent : favoritesListViewComponent
        readonly property string preferredAllAppsViewObjectName: Plasmoid.configuration.applicationsDisplay === 0 ? "listOfGridsView" : "applicationsListView"
        readonly property Component preferredAllAppsViewComponent: Plasmoid.configuration.applicationsDisplay === 0 ? listOfGridsViewComponent : applicationsListViewComponent

        readonly property string preferredAppsViewObjectName: Plasmoid.configuration.applicationsDisplay === 0 ? "applicationsGridView" : "applicationsListView"
        readonly property Component preferredAppsViewComponent: Plasmoid.configuration.applicationsDisplay === 0 ? applicationsGridViewComponent : applicationsListViewComponent
        // NOTE: The 0 index modelForRow isn't supposed to be used. That's just how it works.
        // But to trigger model data update, set initial value to 0
        property int appsModelRow: 0
        readonly property Kicker.AppsModel appsModel: kickoff.rootModel.modelForRow(appsModelRow)
        Connections {
            target: kickoff.rootModel
            function onRefreshed() { // recalculate appsModel binding on rootModel refresh;
                stackView.appsModelRowChanged() // modelForRow does not create dependency
            }
        }
        focus: true
        initialItem: preferredFavoritesViewComponent

        function showSectionView(sectionName: string, parentView: KickoffListView): void {
            stackView.push(applicationsSectionViewComponent, {
                currentSection: sectionName,
                parentView,
            });
        }

        Component {
            id: favoritesListViewComponent
            DropAreaListView {
                id: favoritesListView
                objectName: "favoritesListView"
                mainContentView: true
                focus: true
                model: kickoff.rootModel.favoritesModel
            }
        }

        Component {
            id: favoritesGridViewComponent
            DropAreaGridView {
                id: favoritesGridView
                objectName: "favoritesGridView"
                focus: true
                model: kickoff.rootModel.favoritesModel
            }
        }

        Component {
            id: applicationsListViewComponent

            KickoffListView {
                id: applicationsListView
                objectName: "applicationsListView"
                mainContentView: true
                model: stackView.appsModel
                // we want to semantically switch between group and "", disabling grouping, workaround for QTBUG-121797
                section.property: model && model.description === "KICKER_ALL_MODEL" ? "group" : "_unset"
                section.criteria: ViewSection.FirstCharacter
                hasSectionView: stackView.appsModelRow === 1

                onShowSectionViewRequested: sectionName => {
                    stackView.showSectionView(sectionName, this);
                }
            }
        }

        Component {
            id: applicationsSectionViewComponent

            SectionView {
                id: sectionView
                model: stackView.appsModel.sections

                onHideSectionViewRequested: index => {
                    stackView.pop();
                    stackView.currentItem.view.positionViewAtIndex(index, ListView.Beginning);
                    stackView.currentItem.currentIndex = index;
                }
            }
        }

        Component {
            id: applicationsGridViewComponent
            KickoffGridView {
                id: applicationsGridView
                objectName: "applicationsGridView"
                model: stackView.appsModel
            }
        }

        Component {
            id: listOfGridsViewComponent

            ListOfGridsView {
                id: listOfGridsView
                objectName: "listOfGridsView"
                mainContentView: true
                gridModel: stackView.appsModel

                onShowSectionViewRequested: sectionName => {
                    stackView.showSectionView(sectionName, this);
                }
            }
        }

        // Search results live on the same stackView as the normal app views,
        // so only the right-hand content area is replaced — the sidebar and
        // footer stay visible while searching.
        Component {
            id: searchViewComponent
            KickoffListView {
                id: searchView
                objectName: "searchView"
                mainContentView: true
                model: kickoff.runnerModel.count ? kickoff.runnerModel.modelForRow(0) : null
                delegate: KickoffListDelegate {
                    width: view.availableWidth
                    isSearchResult: true
                }
                section.property: "group"
                activeFocusOnTab: true
                Keys.onTabPressed: event => {
                    kickoff.firstHeaderItem.forceActiveFocus(Qt.TabFocusReason);
                }
                Keys.onBacktabPressed: event => {
                    kickoff.lastHeaderItem.forceActiveFocus(Qt.BacktabFocusReason);
                }
                Keys.onUpPressed: event => {
                    kickoff.searchField.forceActiveFocus(Qt.BacktabFocusReason)
                }

                Loader {
                    anchors.centerIn: searchView.view
                    width: searchView.view.width - (Kirigami.Units.gridUnit * 4)

                    active: searchView.view.count === 0
                    visible: active
                    asynchronous: true

                    sourceComponent: PlasmaExtras.PlaceholderMessage {
                        id: emptyHint
                        iconName: "edit-none"
                        opacity: 0
                        text: i18nc("@info:status", "No matches") // qmllint disable unqualified

                        Connections {
                            target: kickoff.runnerModel
                            function onQueryFinished() {
                                showAnimation.restart()
                            }
                        }

                        NumberAnimation {
                            id: showAnimation
                            duration: Kirigami.Units.longDuration
                            easing.type: Easing.OutCubic
                            property: "opacity"
                            target: emptyHint
                            to: 1
                        }
                    }
                }
            }
        }

        Connections {
            target: kickoff.searchField
            ignoreUnknownSignals: true
            function onTextChanged() {
                const text = kickoff.searchField ? kickoff.searchField.text : ""
                const onSearch = stackView.currentItem
                    && stackView.currentItem.objectName === "searchView"
                if (text.length === 0) {
                    if (onSearch) {
                        // Restore whichever view matches the current sidebar index.
                        if (!root.sideBarItem || root.sideBarItem.currentIndex === 0) {
                            stackView.replace(stackView.preferredFavoritesViewComponent)
                        } else if (root.sideBarItem.currentIndex === 1) {
                            stackView.replace(stackView.preferredAllAppsViewComponent)
                        } else {
                            stackView.replace(stackView.preferredAppsViewComponent)
                        }
                    }
                } else if (!onSearch) {
                    stackView.replace(searchViewComponent)
                }
            }
        }

        onPreferredFavoritesViewComponentChanged: {
            if (root.sideBarItem !== null && root.sideBarItem.currentIndex === 0) {
                stackView.replace(stackView.preferredFavoritesViewComponent)
            }
        }
        onPreferredAllAppsViewComponentChanged: {
            if (root.sideBarItem !== null && root.sideBarItem.currentIndex === 1) {
                stackView.replace(stackView.preferredAllAppsViewComponent)
            }
        }
        onPreferredAppsViewComponentChanged: {
            if (root.sideBarItem !== null && root.sideBarItem.currentIndex > 1) {
                stackView.replace(stackView.preferredAppsViewComponent)
            }
        }

        Connections {
            target: root.sideBarItem
            function onCurrentIndexChanged() {
                // Only update row index if the condition is met.
                // The 0 index modelForRow isn't supposed to be used. That's just how it works.
                if (root.sideBarItem.currentIndex > 0) {
                    stackView.appsModelRow = root.sideBarItem.currentIndex
                }
                if (root.sideBarItem.currentIndex === 0
                    && stackView.currentItem.objectName !== stackView.preferredFavoritesViewObjectName) {
                    stackView.replace(stackView.preferredFavoritesViewComponent)
                } else if (root.sideBarItem.currentIndex === 1
                    && stackView.currentItem.objectName !== stackView.preferredAllAppsViewObjectName) {
                    stackView.replace(stackView.preferredAllAppsViewComponent)
                } else if (root.sideBarItem.currentIndex > 1
                    && stackView.currentItem.objectName !== stackView.preferredAppsViewObjectName) {
                    stackView.replace(stackView.preferredAppsViewComponent)
                }
            }
        }
        Connections {
            target: kickoff
            function onExpandedChanged() {
                if (!kickoff.expanded && kickoff.contentArea.currentItem) {
                    kickoff.contentArea.currentItem.forceActiveFocus()
                }
            }
        }
    }
    // NormalPage doesn't get destroyed when deactivated, so the binding uses
    // StackView.status and visible. This way the bindings are reset when
    // NormalPage is Activated again.
    Binding {
        target: kickoff
        property: "sideBar"
        value: root.sideBarItem
        when: root.T.StackView.status === T.StackView.Active && root.visible
        restoreMode: Binding.RestoreBinding
    }
    Binding {
        target: kickoff
        property: "contentArea"
        value: root.contentAreaItem.currentItem // NOT just root.contentAreaItem
        when: root.T.StackView.status === T.StackView.Active && root.visible
        restoreMode: Binding.RestoreBinding
    }
}
