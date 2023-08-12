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

import SwiftUI
import Common

struct AddingServiceTokenView: View {
    @State private var errorReason: String?
    @State private var rotationAngle = 0.0
    
    @State private var animationProgress: CGFloat = 0
    
    @ObservedObject var presenter: AddingServiceTokenPresenter
    let changeHeight: (CGFloat) -> Void
    
    private let animation = Animation
        .linear(duration: 1)
        .repeatCount(1)
    
    var body: some View {
        VStack(alignment: .center, spacing: Theme.Metrics.standardSpacing) {
            VStack(alignment: .center, spacing: Theme.Metrics.standardSpacing) {
                AddingServiceTitleView(text: "Almost done!")
                AddingServiceTextContentView(text: "To finish pairing, you might need to retype this token in the service.")
                AddingServiceLargeSpacing()
                
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        Image(uiImage: presenter.serviceIcon)
                            .accessibilityHidden(true)
                        
                        VStack(spacing: 4) {
                            AddingServiceTitleView(text: presenter.serviceName, alignToLeading: true)
                                .lineLimit(1)
                            if let serviceAdditionalInfo = presenter.serviceAdditionalInfo {
                                Text(serviceAdditionalInfo)
                                    .font(.footnote)
                                    .foregroundColor(Color(Theme.Colors.Text.subtitle))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)
                            }
                        }
                    }
                    HStack(alignment: .center, spacing: 2 * ThemeMetrics.spacing) {
                        Text(presenter.token)
                            .foregroundColor(Color(
                                presenter.willChangeSoon ? ThemeColor.theme : ThemeColor.primary
                            ))
                            .font(Font(Theme.Fonts.Counter.syncCounter))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        switch presenter.serviceTokenType {
                        case .totp:
                            ZStack(alignment: .center) {
                                Text(presenter.time)
                                    .font(Font(Theme.Fonts.Controls.counter))
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color(
                                        presenter.willChangeSoon ? ThemeColor.theme : ThemeColor.primary
                                    ))
                                
                                Circle()
                                    .trim(from: 0, to: $animationProgress.animation(animation).wrappedValue)
                                    .stroke(Color(presenter.willChangeSoon ? ThemeColor.theme : ThemeColor.primary),
                                            style: StrokeStyle(
                                                lineWidth: 1,
                                                lineCap: .round
                                            ))
                                    .rotationEffect(.degrees(-90))
                                    .padding(0.5)
                                    .frame(width: 30, height: 30)
                            }
                        case .hotp:
                            Button {
                                    withAnimation(
                                        .linear(duration: 1)
                                        .speed(5)
                                        .repeatCount(1, autoreverses: false)
                                    ) {
                                        rotationAngle = 360.0
                                    }
                            } label: {
                                Asset.refreshTokenCounter.swiftUIImage
                                    .tint(Color(presenter.refreshTokenLocked ? ThemeColor.inactive : ThemeColor.theme))
                                    .rotationEffect(.degrees(rotationAngle))
                            }
                            .disabled(presenter.refreshTokenLocked)
                            .onAnimationCompleted(for: rotationAngle) {
                                rotationAngle = 0
                                presenter.handleRefresh()
                            }
                        }
                    }
                }
                .padding(.init(top: 16, leading: 20, bottom: 12, trailing: 20))
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.modalCornerRadius)
                        .stroke(Color(Theme.Colors.Line.separator), lineWidth: 1)
                )
            }.padding(.horizontal, Theme.Metrics.doubleMargin * 3.0 / 4.0)
            
            AddingServiceLargeSpacing()
            
            AddingServiceFullWidthButton(
                text: "Copy code",
                icon: Asset.keybordIcon.swiftUIImage
            ) {
                presenter.handleCopyCode()
            }
        }
        .padding(.horizontal, Theme.Metrics.doubleMargin)
        .observeHeight(onChange: { height in
            changeHeight(height)
        })
        .onChange(of: presenter.part) { newValue in
            withAnimation(animation) {
                animationProgress = newValue
            }
        }
    }
}
