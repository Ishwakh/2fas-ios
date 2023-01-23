//
//  This file is part of the 2FAS iOS app (https://github.com/twofas/2fas-ios)
//  Copyright © 2023 Two Factor Authentication Service, Inc.
//  Contributed by Zbigniew Cisiński. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>
//

import Foundation
import Common
import Token
import Storage

enum TokensModuleInteractorState {
    case normal
    case edit
}

protocol TokensModuleInteracting: AnyObject {
    var isiPhone: Bool { get }
    var canBeDragged: Bool { get }
    var hasServices: Bool { get }
    var count: Int { get }
    var isSortingEnabled: Bool { get }
    var selectedSortType: SortType { get }
    var categoryData: [CategoryData] { get }
    var linkAction: ((TokensLinkAction) -> Void)? { get set }
    var isMainOnlyCategory: Bool { get }
    
    func servicesWereUpdated()
    func sync()
    func enableHOTPCounter(for secret: Secret)
    func stopCounters()
    func setSortType(_ sortType: SortType)
    func checkForNewAppVersion(completion: @escaping (URL) -> Void)
    func skipAppVersion()
    func createSection(with name: String)
    func toggleCollapseSection(_ section: GridSection)
    func moveDown(_ section: GridSection)
    func moveUp(_ section: GridSection)
    func rename(_ section: GridSection, with title: String)
    func delete(_ section: GridSection)
    func moveService(_ service: ServiceData, from old: IndexPath, to new: IndexPath, newSection: SectionData?)
    func copyToken(from serviceData: ServiceData)
    func copyTokenValue(from serviceData: ServiceData) -> String?
    func registerTOTP(_ consumer: TokenTimerConsumer)
    func removeTOTP(_ consumer: TokenTimerConsumer)
    func registerHOTP(_ consumer: TokenCounterConsumer)
    func removeHOTP(_ consumer: TokenCounterConsumer)
    func fetchData(phrase: String?)
    func reloadTokens()
    func createSnapshot(
        state: TokensModuleInteractorState, isSearching: Bool
    ) -> NSDiffableDataSourceSnapshot<GridSection, GridCell>
    func checkCameraPermission(completion: @escaping (Bool) -> Void)
    // MARK: Links
    func handleURLIfNecessary()
    func clearStoredCode()
    func addStoredCode()
    func renameService(newName: String, secret: Secret)
    func cancelRenaming(secret: Secret)
}

final class TokensModuleInteractor {
    private enum TokenTimeType {
        case current(TokenValue)
        case next(TokenValue)
    }
    
    private let nextTokenInteractor: NextTokenInteracting
    private let serviceDefinitionsInteractor: ServiceDefinitionInteracting
    private let serviceInteractor: ServiceListingInteracting
    private let serviceModifyInteractor: ServiceModifyInteracting
    private let sortInteractor: SortInteracting
    private let tokenInteractor: TokenInteracting
    private let sectionInteractor: SectionInteracting
    private let notificationsInteractor: NotificationInteracting
    private let newVersionInteractor: NewVersionInteracting // TODO: Move up in hierarchy
    private let cloudBackupInteractor: CloudBackupStateInteracting
    private let cameraPermissionInteractor: CameraPermissionInteracting
    private let linkInteractor: LinkInteracting // TODO: Move up in hierarchy
    private let widgetsInteractor: WidgetsInteracting
    
    private(set) var categoryData: [CategoryData] = []
    
    var linkAction: ((TokensLinkAction) -> Void)?
    
    init(
        nextTokenInteractor: NextTokenInteracting,
        serviceDefinitionsInteractor: ServiceDefinitionInteracting,
        serviceInteractor: ServiceListingInteracting,
        serviceModifyInteractor: ServiceModifyInteracting,
        sortInteractor: SortInteracting,
        tokenInteractor: TokenInteracting,
        sectionInteractor: SectionInteracting,
        notificationsInteractor: NotificationInteracting,
        newVersionInteractor: NewVersionInteracting,
        cloudBackupInteractor: CloudBackupStateInteracting,
        cameraPermissionInteractor: CameraPermissionInteracting,
        linkInteractor: LinkInteracting,
        widgetsInteractor: WidgetsInteracting
    ) {
        self.nextTokenInteractor = nextTokenInteractor
        self.serviceDefinitionsInteractor = serviceDefinitionsInteractor
        self.serviceInteractor = serviceInteractor
        self.serviceModifyInteractor = serviceModifyInteractor
        self.sortInteractor = sortInteractor
        self.tokenInteractor = tokenInteractor
        self.sectionInteractor = sectionInteractor
        self.notificationsInteractor = notificationsInteractor
        self.newVersionInteractor = newVersionInteractor
        self.cloudBackupInteractor = cloudBackupInteractor
        self.cameraPermissionInteractor = cameraPermissionInteractor
        self.linkInteractor = linkInteractor
        self.widgetsInteractor = widgetsInteractor
        
        setupLinkInteractor()
    }
}

extension TokensModuleInteractor: TokensModuleInteracting {
    var isiPhone: Bool {
        !UIDevice.isiPad
    }
    
    var canBeDragged: Bool {
        sortInteractor.canDrag
    }
    
    var hasServices: Bool {
        count > 0
    }
    
    var count: Int {
        categoryData.flatMap { $0.services }.count
    }
    
    func sync() {
        cloudBackupInteractor.synchronizeBackup()
    }
    
    var isMainOnlyCategory: Bool {
        categoryData.contains(where: { $0.section == nil }) && categoryData.count == 1
    }
    
    // MARK: - Links
    
    func handleURLIfNecessary() {
        linkInteractor.handleURLIfNecessary()
    }
    
    func clearStoredCode() {
        linkInteractor.clearStoredCode()
    }
    
    func addStoredCode() {
        linkInteractor.addStoredCode()
    }
    
    func renameService(newName: String, secret: Secret) {
        linkInteractor.renameService(newName: newName, secret: secret)
    }
    
    func cancelRenaming(secret: Secret) {
        linkInteractor.cancelRenaming(secret: secret)
    }
    
    // MARK: - Camera permissions
    
    func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        if cameraPermissionInteractor.isCameraAvailable == false {
            completion(false)
            return
        }
        cameraPermissionInteractor.checkPermission { value in
            completion(value)
        }
    }
    
    // MARK: - Tokens
    
    func enableHOTPCounter(for secret: Secret) {
        tokenInteractor.unlockCounter(for: secret)
    }
    
    func stopCounters() {
        tokenInteractor.stopTimers()
    }
    
    func copyToken(from serviceData: ServiceData) {
        guard let token = tokenTypeForService(serviceData) else { return }
        switch token {
        case .current(let tokenValue):
            copyToken(tokenValue)
        case .next(let tokenValue):
            copyNextToken(tokenValue)
        }
    }
    
    func copyTokenValue(from serviceData: ServiceData) -> String? {
        guard let token = tokenTypeForService(serviceData) else { return nil }
        switch token {
        case .current(let tokenValue):
            return tokenValue
        case .next(let tokenValue):
            return tokenValue
        }
    }
    
    // MARK: - Sort type
    
    var isSortingEnabled: Bool {
        sortInteractor.currentSort != .manual
    }
    
    var selectedSortType: SortType {
        sortInteractor.currentSort
    }
    
    func setSortType(_ sortType: SortType) {
        sortInteractor.setSort(sortType)
    }
    
    // MARK: - New app version
    
    func checkForNewAppVersion(completion: @escaping (URL) -> Void) {
        newVersionInteractor.checkForNewVersion { [weak self] newVersionAvailable in
            guard let appStoreURL = self?.newVersionInteractor.appStoreURL, newVersionAvailable else { return }
            completion(appStoreURL)
        }
    }
    
    func skipAppVersion() {
        newVersionInteractor.userSkippedVersion()
    }
    
    // MARK: - Section
    
    func createSection(with name: String) {
        AnalyticsLog(.groupAdd)
        sectionInteractor.create(with: name)
    }
    
    func toggleCollapseSection(_ section: GridSection) {
        let toggleValue = !section.isCollapsed
        if let sectionData = section.sectionData {
            sectionInteractor.collapse(sectionData, isCollapsed: toggleValue)
        } else {
            sectionInteractor.setSectionZeroIsCollapsed(toggleValue)
        }
    }

    func moveDown(_ section: GridSection) {
        guard let sectionData = section.sectionData else { return }
        sectionInteractor.moveDown(sectionData)
    }

    func moveUp(_ section: GridSection) {
        guard let sectionData = section.sectionData else { return }
        sectionInteractor.moveUp(sectionData)
    }

    func rename(_ section: GridSection, with title: String) {
        guard let sectionData = section.sectionData else { return }
        sectionInteractor.rename(sectionData, newTitle: title)
    }

    func delete(_ section: GridSection) {
        guard let sectionData = section.sectionData else { return }
        AnalyticsLog(.groupRemove)
        sectionInteractor.delete(sectionData)
    }
    
    // MARK: - Service
    
    func servicesWereUpdated() {
        widgetsInteractor.reload()
    }
    
    func moveService(_ service: ServiceData, from old: IndexPath, to new: IndexPath, newSection: SectionData?) {
        let oldRow = old.row
        let newRow = new.row
        
        sectionInteractor.move(service: service, from: oldRow, to: newRow, newSection: newSection)
    }
    
    // MARK: - Timer and Counter support
    
    func registerTOTP(_ consumer: TokenTimerConsumer) {
        tokenInteractor.registerTOTP(consumer)
    }
    
    func removeTOTP(_ consumer: TokenTimerConsumer) {
        tokenInteractor.removeTOTP(consumer)
    }
    
    func registerHOTP(_ consumer: TokenCounterConsumer) {
        tokenInteractor.registerHOTP(consumer)
    }
    
    func removeHOTP(_ consumer: TokenCounterConsumer) {
        tokenInteractor.removeHOTP(consumer)
    }
    
    // MARK: - Data rendering
    
    func fetchData(phrase: String?) {
        if let p = phrase, !p.isEmpty {
            let tags = serviceDefinitionsInteractor.findServices(byTag: p).map({ $0.serviceTypeID })
            categoryData = sectionInteractor.findServices(for: p, sort: sortInteractor.currentSort, tags: tags)
        } else {
            categoryData = sectionInteractor.listAll(sort: sortInteractor.currentSort)
        }
        return
    }
    
    func reloadTokens() {
        let allServices = categoryData.allServices
        let totp = allServices.filter { $0.tokenType == .totp }
        let hotp = allServices.filter { $0.tokenType == .hotp }
        tokenInteractor.start(timedSecrets: totp.map {
            TimedSecret(
                secret: $0.secret,
                period: $0.tokenPeriod ?? .defaultValue,
                digits: $0.tokenLength,
                algorithm: $0.algorithm)
        }, counterSecrets: hotp.map {
            CounterSecret(
                secret: $0.secret,
                counter: $0.counter ?? TokenType.hotpDefaultValue,
                digits: $0.tokenLength,
                algorithm: $0.algorithm
            )
        })
    }
    
    func createSnapshot(
        state: TokensModuleInteractorState,
        isSearching: Bool
    ) -> NSDiffableDataSourceSnapshot<GridSection, GridCell> {
        let snapshot: NSDiffableDataSourceSnapshot<GridSection, GridCell>
        switch state {
        case .normal: snapshot = createNormalSnapshot(isSearching: isSearching)
        case .edit: snapshot = createEditSnapshot(isSearching: isSearching)
        }
        
        return snapshot
    }
}

private extension TokensModuleInteractor {
    func setupLinkInteractor() {
        linkInteractor.showCodeAlreadyExists = { [weak self] in self?.linkAction?(.codeAlreadyExists) }
        linkInteractor.showShouldAddCode = { [weak self] in self?.linkAction?(.shouldAddCode(descriptionText: $0)) }
        linkInteractor.showSendLogs = { [weak self] in self?.linkAction?(.sendLogs(auditID: $0)) }
        linkInteractor.reloadDataAndRefresh = { [weak self] in self?.linkAction?(.newData) }
        linkInteractor.shouldRename = { [weak self] currentName, secret in
            self?.linkAction?(.shouldRename(currentName: currentName, secret: secret))
        }
        linkInteractor.serviceWasCreated = { [weak self] in self?.linkAction?(.serviceWasCreaded(serviceData: $0)) }
    }
    
    func createNormalSnapshot(isSearching: Bool) -> NSDiffableDataSourceSnapshot<GridSection, GridCell> {
        var snapshot = NSDiffableDataSourceSnapshot<GridSection, GridCell>()
        var sections: [GridSection] = []
        
        var startIndex: Int = 0
        var currentIndex: Int = 0
        var totalIndex: Int = categoryData.count - 1
        
        if categoryData.contains(where: { $0.section == nil }) {
            startIndex = 1
            totalIndex -= 1
        }
        
        let data = categoryData.reduce([GridSection: [GridCell]]()) { dict, category -> [GridSection: [GridCell]] in
            var dict = dict
            let gridCells = category.services
            let gridSection = GridSection(
                title: category.section?.title,
                sectionID: category.section?.sectionID,
                sectionData: category.section,
                isCollapsed: category.section?.isCollapsed ?? (
                    sectionInteractor.isSectionZeroCollapsed && !isMainOnlyCategory
                ),
                elementCount: gridCells.count,
                isSearching: isSearching,
                position: sectionPosition(for: startIndex, currentIndex: currentIndex, totalIndex: totalIndex)
            )
            currentIndex += 1
            
            if (isSearching && !gridCells.isEmpty) || !isSearching {
                sections.append(gridSection)
                
                if !gridSection.isCollapsed || isSearching {
                    dict[gridSection] = gridCells.map { createCell(with: $0) }
                }
            }
            return dict
        }
        snapshot.appendSections(sections)
        data.forEach { key, value in
            snapshot.appendItems(value, toSection: key)
        }
        return snapshot
    }

    func createEditSnapshot(isSearching: Bool) -> NSDiffableDataSourceSnapshot<GridSection, GridCell> {
        var snapshot = NSDiffableDataSourceSnapshot<GridSection, GridCell>()
        
        let startIndex: Int = 1
        var currentIndex: Int = 0
        let totalIndex: Int = categoryData.count - 1
        
        if !categoryData.contains(where: { $0.section == nil }) {
            let emptySection = GridSection(
                title: nil,
                sectionID: nil,
                sectionData: nil,
                isCollapsed: false,
                elementCount: 0,
                isSearching: isSearching,
                position: .notUsed
            )
            snapshot.appendSections([emptySection])
            snapshot.appendItems([createEmptyCell()], toSection: emptySection)
            currentIndex += 1
        }
        var sections: [GridSection] = []
        let data = categoryData.reduce([GridSection: [GridCell]]()) { dict, category -> [GridSection: [GridCell]] in
            var dict = dict
            let gridCells = category.services
            let gridSection = GridSection(
                title: category.section?.title,
                sectionID: category.section?.sectionID,
                sectionData: category.section,
                isCollapsed: false,
                elementCount: gridCells.count,
                isSearching: isSearching,
                position: sectionPosition(for: startIndex, currentIndex: currentIndex, totalIndex: totalIndex)
            )
            currentIndex += 1
            
            if (isSearching && !gridCells.isEmpty) || !isSearching {
                sections.append(gridSection)
                
                if category.services.isEmpty {
                    dict[gridSection] = [createEmptyCell()]
                } else {
                    dict[gridSection] = gridCells.map { createCell(with: $0) }
                }
            }
            return dict
        }
        snapshot.appendSections(sections)
        data.forEach { key, value in
            snapshot.appendItems(value, toSection: key)
        }
        return snapshot
    }

    func createCell(with serviceData: ServiceData) -> GridCell {
        let cellType: GridCell.CellType = {
            switch serviceData.tokenType {
            case .totp: return .serviceTOTP
            case .hotp: return .serviceHOTP
            }
        }()
        return .init(
            name: serviceData.name,
            secret: serviceData.secret,
            cellType: cellType,
            serviceTypeName: serviceDefinitionsInteractor.serviceName(for: serviceData.serviceTypeID) ?? "",
            additionalInfo: serviceData.additionalInfo ?? "",
            iconType: serviceData.iconTypeParsed,
            category: serviceData.categoryColor,
            serviceData: serviceData,
            canBeDragged: canBeDragged,
            useNextToken: nextTokenInteractor.isEnabled
        )
    }

    func createEmptyCell() -> GridCell {
        .init(
            name: "",
            secret: UUID().uuidString,
            cellType: .placeholder,
            serviceTypeName: "",
            additionalInfo: "",
            iconType: .image(UIImage()),
            category: TintColor.green,
            serviceData: nil,
            canBeDragged: canBeDragged,
            useNextToken: nextTokenInteractor.isEnabled
        )
    }
    
    func sectionPosition(for startIndex: Int, currentIndex: Int, totalIndex: Int) -> GridSection.Position {
        guard startIndex <= currentIndex || totalIndex > 1  else { return .notUsed }
        if startIndex == currentIndex {
            return .first
        } else if currentIndex == totalIndex {
            return .last
        }
        
        return .middle
    }
    
    private func tokenTypeForService(_ serviceData: ServiceData) -> TokenTimeType? {
        let secret = serviceData.secret
        
        if serviceData.tokenType == .totp {
            guard let token = tokenInteractor.TOTPToken(for: secret) else { return nil }
            if nextTokenInteractor.isEnabled && token.willChangeSoon {
                return .next(token.next)
            }
            return .current(token.current)
        }
        guard let token = tokenInteractor.HOTPToken(for: secret) else { return nil }
        return .current(token)
    }

    func copyToken(_ token: String) {
        notificationsInteractor.copyWithSuccess(
            title: T.Notifications.tokenCopied,
            value: token,
            accessibilityTitle: T.Notifications.tokenCopied
        )
    }
    
    func copyNextToken(_ token: String) {
        notificationsInteractor.copyWithSuccess(
            title: T.Notifications.nextTokenCopied,
            value: token,
            accessibilityTitle: T.Notifications.nextTokenCopied
        )
    }
}

private extension ServiceData {
    var categoryColor: TintColor { self.badgeColor ?? .default }
    
    var iconTypeParsed: GridCollectionViewCell.IconType {
        switch iconType {
        case .brand:
            return .image(ServiceIcon.for(iconTypeID: iconTypeID))
        case .label:
            return .label(labelTitle, labelColor)
        }
    }
}
