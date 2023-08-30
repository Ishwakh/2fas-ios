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

import UIKit
import Common

final class TokensEditCell: UICollectionViewCell {
    static let reuseIdentifier = "TokensEditCell"
    
    private let hMargin: CGFloat = Theme.Metrics.doubleMargin
    private let vMargin: CGFloat = Theme.Metrics.mediumMargin
    private let dragHandlesWidth: CGFloat = 16
    
    private let categoryView = TokensCategory()
    private var logoView: TokensLogo = {
        let comp = TokensLogo()
        comp.setKind(.edit)
        return comp
    }()
    private var serviceNameLabel: TokensServiceName = {
        let comp = TokensServiceName()
        comp.setKind(.edit)
        return comp
    }()
    private var additionalInfoLabel: TokensAdditionalInfo = {
        let comp = TokensAdditionalInfo()
        comp.setKind(.edit)
        return comp
    }()
    private var dragHandles: UIImageView = {
        let imageView = UIImageView(image: Asset.dragHandles.image)
        imageView.contentMode = .center
        imageView.tintColor = Theme.Colors.Icon.more
        return imageView
    }()
    
    private var bottomNameConstraint: NSLayoutConstraint?
    private var bottomAdditionalNameConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        setupBackground()
        setupLayout()
    }
    
    func update(
        name: String,
        additionalInfo: String?,
        serviceTypeName: String,
        logoType: LogoType,
        category: TintColor,
        canBeDragged: Bool
    ) {
        serviceNameLabel.setText(name)
        if let additionalInfo, !additionalInfo.isEmpty {
            additionalInfoLabel.setText(additionalInfo)
            additionalInfoLabel.isHidden = false
            bottomNameConstraint?.isActive = false
            bottomAdditionalNameConstraint?.isActive = true
        } else {
            additionalInfoLabel.isHidden = true
            bottomNameConstraint?.isActive = true
            bottomAdditionalNameConstraint?.isActive = false
        }

        categoryView.setColor(category)
        logoView.configure(with: logoType)
        dragHandles.isHidden = !canBeDragged
    }
    
    private func setupBackground() {
        contentView.backgroundColor = Theme.Colors.Fill.background
        backgroundColor = Theme.Colors.Fill.background
    }
    
    private func setupLayout() {
        contentView.addSubview(categoryView, with: [
            categoryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            categoryView.topAnchor.constraint(equalTo: contentView.topAnchor),
            categoryView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        contentView.addSubview(logoView, with: [
            logoView.leadingAnchor.constraint(equalTo: categoryView.trailingAnchor, constant: hMargin),
            logoView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: vMargin),
            logoView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -vMargin)
        ])
        
        contentView.addSubview(serviceNameLabel, with: [
            serviceNameLabel.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: hMargin),
            serviceNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: vMargin)
        ])
        
        bottomNameConstraint = serviceNameLabel.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -vMargin
        )
        
        contentView.addSubview(additionalInfoLabel, with: [
            additionalInfoLabel.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: hMargin),
            additionalInfoLabel.topAnchor.constraint(equalTo: serviceNameLabel.bottomAnchor),
            additionalInfoLabel.heightAnchor.constraint(equalTo: serviceNameLabel.heightAnchor),
            additionalInfoLabel.widthAnchor.constraint(equalTo: serviceNameLabel.widthAnchor)
        ])
        
        bottomAdditionalNameConstraint = additionalInfoLabel.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -vMargin
        )
        
        contentView.addSubview(dragHandles, with: [
            dragHandles.leadingAnchor.constraint(equalTo: serviceNameLabel.trailingAnchor, constant: hMargin),
            dragHandles.leadingAnchor.constraint(equalTo: additionalInfoLabel.trailingAnchor, constant: hMargin),
            dragHandles.topAnchor.constraint(equalTo: contentView.topAnchor, constant: vMargin),
            dragHandles.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -vMargin),
            dragHandles.widthAnchor.constraint(equalToConstant: dragHandlesWidth),
            dragHandles.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -hMargin)
        ])
    }
}
