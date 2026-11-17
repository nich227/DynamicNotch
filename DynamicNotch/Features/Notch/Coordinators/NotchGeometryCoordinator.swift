//
//  NotchGeometryCoordinator.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 11/10/26.
//

import SwiftUI
import Combine

struct CalculatedNotchGeometry {
    let width: CGFloat
    let height: CGFloat
    let scale: CGFloat
    let topInset: CGFloat
    let isDynamicIsland: Bool
    let dynamicIslandTopOffset: CGFloat
}

enum DynamicIslandMenuBarFit {
    nonisolated static let margin: CGFloat = 2

    /// The factor shrinks an island of the given height to fit inside the menu bar.
    /// The factor is 1 when the island already fits or the menu bar height is unknown.
    nonisolated static func scale(islandHeight: CGFloat, menuBarHeight: CGFloat?) -> CGFloat {
        guard let menuBarHeight, islandHeight > 0 else { return 1 }

        let availableHeight = menuBarHeight - margin * 2
        guard availableHeight > 0 else { return 1 }

        return min(1, availableHeight / islandHeight)
    }

    /// This is the distance from the top of the screen that centers the island in the menu bar.
    /// The value is nil when the menu bar height is unknown or the island is taller than the menu bar.
    nonisolated static func topInset(islandHeight: CGFloat, menuBarHeight: CGFloat?) -> CGFloat? {
        guard let menuBarHeight, islandHeight <= menuBarHeight else { return nil }

        return (menuBarHeight - islandHeight) / 2
    }
}

@MainActor
final class NotchGeometryCoordinator: ObservableObject {
    @Published var stagedNotchHeight: CGFloat
    @Published var topInset: CGFloat = 0

    var isClosingHeightStaged = false

    nonisolated static let defaultDynamicIslandTopOffset: CGFloat = 9
    private static let dynamicIslandWidthFactor: CGFloat = 0.85

    var isDynamicIsland: Bool {
        topInset == 0
    }

    init(initialBaseHeight: CGFloat? = nil) {
        self.stagedNotchHeight = initialBaseHeight ?? NotchModel().baseHeight
    }

    func calculateGeometry(
        screenMetrics: NotchScreenMetrics,
        notchWidthSetting: Double,
        notchHeightSetting: Double
    ) -> CalculatedNotchGeometry {
        let topInset = screenMetrics.topInset
        let screenWidth = screenMetrics.width
        let baseScreenWidth: CGFloat = 1440.0
        let scale = max(0.35, screenWidth / baseScreenWidth)
        let widthScale = scale > 1.0 ? 1.0 + (scale - 1.0) * 0.35 : scale

        let isDynamicIsland = topInset == 0
        let widthOffset = CGFloat(notchWidthSetting) + 2
        let heightOffset = CGFloat(notchHeightSetting)
        let baseHeightAdjustment: CGFloat = isDynamicIsland ? 5 : 0

        var finalWidth: CGFloat
        var finalHeight: CGFloat

        if let notchSize = screenMetrics.notchSize {
            let baseWidth = notchSize.width + 14.scaled(by: widthScale) + widthOffset
            finalWidth = isDynamicIsland ? baseWidth * Self.dynamicIslandWidthFactor : baseWidth
            finalHeight = notchSize.height + heightOffset + baseHeightAdjustment
        } else {
            let baseWidthValue: CGFloat = isDynamicIsland ? 90 : 190
            let baseWidth = (baseWidthValue * widthScale) + widthOffset
            finalWidth = isDynamicIsland ? baseWidth * Self.dynamicIslandWidthFactor : baseWidth
            finalHeight = 26 + heightOffset + baseHeightAdjustment
        }

        var dynamicIslandTopOffset = Self.defaultDynamicIslandTopOffset

        if isDynamicIsland {
            let menuBarHeight = screenMetrics.menuBarHeight
            let widthSettingOffset = CGFloat(notchWidthSetting) * Self.dynamicIslandWidthFactor
            let fitScale = DynamicIslandMenuBarFit.scale(
                islandHeight: finalHeight - heightOffset,
                menuBarHeight: menuBarHeight
            )

            if fitScale < 1 {
                finalWidth = (finalWidth - widthSettingOffset) * fitScale + widthSettingOffset
                finalHeight = (finalHeight - heightOffset) * fitScale + heightOffset
            }

            if let menuBarInset = DynamicIslandMenuBarFit.topInset(
                islandHeight: finalHeight,
                menuBarHeight: menuBarHeight
            ) {
                // The notch window starts 1 point above the top of the screen.
                dynamicIslandTopOffset = menuBarInset + 1
            }
        }

        return CalculatedNotchGeometry(
            width: finalWidth,
            height: finalHeight,
            scale: scale,
            topInset: topInset,
            isDynamicIsland: isDynamicIsland,
            dynamicIslandTopOffset: dynamicIslandTopOffset
        )
    }

    func scheduleStagedHeightUpdate(
        to targetHeight: CGFloat,
        isSwipeInteractionActive: Bool,
        animation: Animation?
    ) {
        guard !isSwipeInteractionActive else {
            isClosingHeightStaged = false
            stagedNotchHeight = targetHeight
            return
        }

        let currentHeight = stagedNotchHeight

        guard abs(currentHeight - targetHeight) > 0.5 else {
            isClosingHeightStaged = false
            stagedNotchHeight = targetHeight
            return
        }

        guard targetHeight < currentHeight else {
            isClosingHeightStaged = false
            stagedNotchHeight = targetHeight
            return
        }

        isClosingHeightStaged = false
        applyStagedHeight(targetHeight, animation: animation)
    }

    func applyStagedHeight(_ targetHeight: CGFloat, animation: Animation?) {
        guard let animation else {
            stagedNotchHeight = targetHeight
            return
        }

        withAnimation(animation) {
            stagedNotchHeight = targetHeight
        }
    }

    func interactiveCornerRadius(
        baseCornerRadius: (top: CGFloat, bottom: CGFloat),
        focusCloseStretchHeight: CGFloat,
        notchPulseHeight: CGFloat
    ) -> (top: CGFloat, bottom: CGFloat) {
        let radiusOffset = (focusCloseStretchHeight + notchPulseHeight) * 0.3
        return (
            top: baseCornerRadius.top + radiusOffset,
            bottom: baseCornerRadius.bottom + radiusOffset
        )
    }

    func dynamicIslandCornerRadius(
        height: CGFloat,
        isDisplayingExpandedLiveActivity: Bool,
        displayedContent: NotchContentProtocol?,
        gestureExpansion: CGFloat
    ) -> CGFloat {
        let baseRadius: CGFloat
        if isDisplayingExpandedLiveActivity {
            if let customizable = displayedContent {
                baseRadius = customizable.expandedDynamicIslandCornerRadius(baseHeight: height)
            } else {
                baseRadius = height * 0.2
            }
        } else {
            if let customizable = displayedContent {
                baseRadius = customizable.dynamicIslandCornerRadius(baseHeight: height)
            } else {
                baseRadius = height * 0.5
            }
        }
        return baseRadius + gestureExpansion
    }
}
