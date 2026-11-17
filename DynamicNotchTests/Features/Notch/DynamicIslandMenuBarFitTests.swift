import XCTest
@testable import DynamicNotch

final class DynamicIslandMenuBarFitTests: XCTestCase {
    private let defaultIslandHeight: CGFloat = 31
    private let menuBarHeight: CGFloat = 30

    // MARK: - Scale

    func testScaleShrinksTheIslandToTheMenuBarHeightLessTheMargins() {
        let scale = DynamicIslandMenuBarFit.scale(islandHeight: defaultIslandHeight, menuBarHeight: menuBarHeight)

        XCTAssertEqual(scale, 26.0 / 31.0, accuracy: 0.0001)
        XCTAssertEqual(defaultIslandHeight * scale, menuBarHeight - DynamicIslandMenuBarFit.margin * 2, accuracy: 0.0001)
    }

    func testScaleIsOneWhenTheIslandAlreadyFits() {
        XCTAssertEqual(DynamicIslandMenuBarFit.scale(islandHeight: defaultIslandHeight, menuBarHeight: 35), 1)
        XCTAssertEqual(DynamicIslandMenuBarFit.scale(islandHeight: defaultIslandHeight, menuBarHeight: 60), 1)
    }

    func testScaleIsOneWhenTheMenuBarHeightIsUnknown() {
        XCTAssertEqual(DynamicIslandMenuBarFit.scale(islandHeight: defaultIslandHeight, menuBarHeight: nil), 1)
    }

    func testScaleIsOneWhenTheMenuBarLeavesNoRoomForTheIsland() {
        XCTAssertEqual(DynamicIslandMenuBarFit.scale(islandHeight: defaultIslandHeight, menuBarHeight: 0), 1)
        XCTAssertEqual(
            DynamicIslandMenuBarFit.scale(
                islandHeight: defaultIslandHeight,
                menuBarHeight: DynamicIslandMenuBarFit.margin * 2
            ),
            1
        )
    }

    func testScaleIsOneWhenTheIslandHasNoHeight() {
        XCTAssertEqual(DynamicIslandMenuBarFit.scale(islandHeight: 0, menuBarHeight: menuBarHeight), 1)
    }

    // MARK: - Top inset

    func testTopInsetCentersTheIslandInTheMenuBar() throws {
        let topInset = try XCTUnwrap(DynamicIslandMenuBarFit.topInset(islandHeight: 26, menuBarHeight: menuBarHeight))
        XCTAssertEqual(topInset, 2, accuracy: 0.0001)

        let fullHeightInset = try XCTUnwrap(DynamicIslandMenuBarFit.topInset(islandHeight: 30, menuBarHeight: menuBarHeight))
        XCTAssertEqual(fullHeightInset, 0, accuracy: 0.0001)
    }

    func testTopInsetIsNilWhenTheMenuBarHeightIsUnknown() {
        XCTAssertNil(DynamicIslandMenuBarFit.topInset(islandHeight: 26, menuBarHeight: nil))
    }

    func testTopInsetIsNilWhenTheIslandIsTallerThanTheMenuBar() {
        XCTAssertNil(DynamicIslandMenuBarFit.topInset(islandHeight: defaultIslandHeight, menuBarHeight: menuBarHeight))
    }

    // MARK: - Geometry on a display without a notch

    @MainActor
    func testIslandFitsInsideTheMenuBarAndKeepsItsAspectRatio() {
        let legacy = geometry(menuBarHeight: nil)
        let fitted = geometry(menuBarHeight: menuBarHeight)

        XCTAssertTrue(fitted.isDynamicIsland)
        XCTAssertEqual(legacy.height, 31, accuracy: 0.0001)
        XCTAssertEqual(fitted.height, 26, accuracy: 0.0001)
        XCTAssertEqual(fitted.width, legacy.width * 26 / 31, accuracy: 0.0001)
        XCTAssertEqual(fitted.width / fitted.height, legacy.width / legacy.height, accuracy: 0.0001)

        let topInset = fitted.dynamicIslandTopOffset - 1
        XCTAssertEqual(topInset, 2, accuracy: 0.0001)
        XCTAssertEqual(topInset + fitted.height, menuBarHeight - 2, accuracy: 0.0001)
    }

    @MainActor
    func testIslandKeepsItsSizeAndOffsetWhenTheMenuBarHeightIsUnknown() {
        let legacy = geometry(menuBarHeight: nil)
        let widthScale: CGFloat = 1 + (3008.0 / 1440.0 - 1) * 0.35

        XCTAssertEqual(legacy.width, (90 * widthScale + 2) * 0.85, accuracy: 0.0001)
        XCTAssertEqual(legacy.height, 31, accuracy: 0.0001)
        XCTAssertEqual(legacy.dynamicIslandTopOffset, 9, accuracy: 0.0001)
    }

    @MainActor
    func testIslandKeepsItsSizeAndIsCenteredWhenTheMenuBarIsTallEnough() {
        let legacy = geometry(menuBarHeight: nil)
        let roomy = geometry(menuBarHeight: 41)

        XCTAssertEqual(roomy.width, legacy.width)
        XCTAssertEqual(roomy.height, legacy.height)
        XCTAssertEqual(roomy.dynamicIslandTopOffset, 6, accuracy: 0.0001)
    }

    @MainActor
    func testSizeSettingsStayOffsetsOnTopOfTheFittedSize() {
        let fitted = geometry(menuBarHeight: menuBarHeight)
        let adjusted = geometry(menuBarHeight: menuBarHeight, notchWidthSetting: 5, notchHeightSetting: 1)
        let legacy = geometry(menuBarHeight: nil)
        let legacyAdjusted = geometry(menuBarHeight: nil, notchWidthSetting: 5, notchHeightSetting: 1)

        XCTAssertEqual(adjusted.width - fitted.width, legacyAdjusted.width - legacy.width, accuracy: 0.0001)
        XCTAssertEqual(adjusted.width - fitted.width, 5 * 0.85, accuracy: 0.0001)
        XCTAssertEqual(adjusted.height - fitted.height, 1, accuracy: 0.0001)
        XCTAssertEqual(adjusted.dynamicIslandTopOffset - 1, 1.5, accuracy: 0.0001)

        let narrowed = geometry(menuBarHeight: menuBarHeight, notchWidthSetting: -5, notchHeightSetting: -1)
        XCTAssertEqual(narrowed.width - fitted.width, -5 * 0.85, accuracy: 0.0001)
        XCTAssertEqual(narrowed.height - fitted.height, -1, accuracy: 0.0001)
    }

    @MainActor
    func testIslandFitsWhenTheScreenReportsANotchSizeWithoutATopInset() {
        let metrics: NotchScreenMetrics = (
            width: 1440,
            topInset: 0,
            notchSize: CGSize(width: 190, height: 32),
            menuBarHeight: menuBarHeight
        )
        let legacyMetrics: NotchScreenMetrics = (
            width: 1440,
            topInset: 0,
            notchSize: CGSize(width: 190, height: 32),
            menuBarHeight: nil
        )
        let fitted = geometry(metrics: metrics)
        let legacy = geometry(metrics: legacyMetrics)

        XCTAssertEqual(legacy.height, 37, accuracy: 0.0001)
        XCTAssertEqual(fitted.height, 26, accuracy: 0.0001)
        XCTAssertEqual(fitted.width / fitted.height, legacy.width / legacy.height, accuracy: 0.0001)
    }

    // MARK: - Geometry on a display with a notch

    @MainActor
    func testNotchedDisplayIgnoresTheMenuBarHeight() {
        let notchSize = CGSize(width: 185, height: 32)
        let withMenuBar = geometry(
            metrics: (width: 1728, topInset: 32, notchSize: notchSize, menuBarHeight: 32),
            notchWidthSetting: 3,
            notchHeightSetting: 1
        )
        let withoutMenuBar = geometry(
            metrics: (width: 1728, topInset: 32, notchSize: notchSize, menuBarHeight: nil),
            notchWidthSetting: 3,
            notchHeightSetting: 1
        )
        let shortMenuBar = geometry(
            metrics: (width: 1728, topInset: 32, notchSize: notchSize, menuBarHeight: 10),
            notchWidthSetting: 3,
            notchHeightSetting: 1
        )
        let widthScale: CGFloat = 1 + (1728.0 / 1440.0 - 1) * 0.35

        XCTAssertFalse(withMenuBar.isDynamicIsland)
        XCTAssertEqual(withMenuBar.width, 185 + 14 * widthScale + 5, accuracy: 0.0001)
        XCTAssertEqual(withMenuBar.height, 33)
        XCTAssertEqual(withMenuBar.topInset, 32)

        for other in [withoutMenuBar, shortMenuBar] {
            XCTAssertEqual(other.width, withMenuBar.width)
            XCTAssertEqual(other.height, withMenuBar.height)
            XCTAssertEqual(other.scale, withMenuBar.scale)
            XCTAssertEqual(other.dynamicIslandTopOffset, withMenuBar.dynamicIslandTopOffset)
        }
    }

    // MARK: - Content scale

    @MainActor
    func testContentOnAWideDisplayWithoutANotchUsesTheDampedScale() {
        // 3008 / 1440 is about 2.09. The island grows by 35% of the amount above 1.
        let expected = 1 + (3008.0 / 1440.0 - 1) * 0.35

        XCTAssertEqual(geometry(menuBarHeight: menuBarHeight).scale, expected, accuracy: 0.0001)
        XCTAssertEqual(geometry(menuBarHeight: nil).scale, expected, accuracy: 0.0001)
    }

    @MainActor
    func testContentOnASmallDisplayWithoutANotchKeepsItsScale() {
        let small = geometry(metrics: (width: 1280, topInset: 0, notchSize: nil, menuBarHeight: 24))

        XCTAssertEqual(small.scale, 1280.0 / 1440.0, accuracy: 0.0001)
    }

    @MainActor
    func testContentOnADisplayWithANotchKeepsTheFullScale() {
        let notched = geometry(
            metrics: (width: 1728, topInset: 32, notchSize: CGSize(width: 185, height: 32), menuBarHeight: 32)
        )

        XCTAssertFalse(notched.isDynamicIsland)
        XCTAssertEqual(notched.scale, 1728.0 / 1440.0, accuracy: 0.0001)
    }

    @MainActor
    func testNowPlayingPillContentStaysBesideTheMiddleOfTheIsland() {
        let fitted = geometry(menuBarHeight: menuBarHeight)
        // The pill is 65 points wider than the island, so each side is 32.5 points wide. The artwork is 20 points
        // wide after 7 scaled points, and the equalizer is 18 points wide before 9 scaled points.
        let side: CGFloat = 65 / 2

        XCTAssertLessThanOrEqual(7 * fitted.scale + 20, side)
        XCTAssertLessThanOrEqual(9 * fitted.scale + 18, side)
    }

    // MARK: - Panels

    @MainActor
    func testFitReportsTheSizeBeforeTheFit() throws {
        let fitted = geometry(menuBarHeight: menuBarHeight)
        let unfitted = geometry(menuBarHeight: nil)

        let panelBaseSize = try XCTUnwrap(fitted.panelBaseSize)
        XCTAssertEqual(panelBaseSize.width, unfitted.width, accuracy: 0.0001)
        XCTAssertEqual(panelBaseSize.height, unfitted.height, accuracy: 0.0001)
        XCTAssertNil(unfitted.panelBaseSize)
        XCTAssertNil(geometry(menuBarHeight: 60).panelBaseSize)
    }

    func testPillKeepsTheFittedHeight() {
        let pill = TestNotchContent(id: "pill", priority: 1, collapsedWidthOffset: 65)
        let model = fittedModel(content: pill)

        XCTAssertEqual(model.size, CGSize(width: 90 + 65, height: 26))
    }

    func testPanelKeepsTheSizeItHasWithoutTheFit() {
        let panel = TestNotchContent(id: "panel", priority: 1, collapsedWidthOffset: 180, collapsedHeightOffset: 100)
        let model = fittedModel(content: panel)

        XCTAssertEqual(model.size, CGSize(width: 107 + 180, height: 31 + 100))
    }

    func testExpandedPanelKeepsTheSizeItHasWithoutTheFit() {
        let player = TestNotchContent(
            id: "player",
            priority: 1,
            isExpandable: true,
            expandedWidthOffset: 210,
            expandedHeightOffset: 150
        )
        var model = fittedModel(content: player)
        model.isExpanded = true

        // The Dynamic Island adds 40 points to the expanded width.
        XCTAssertEqual(model.size, CGSize(width: 107 + 210 + 40, height: 31 + 150))
    }

    func testPanelUsesTheBaseSizeWhenTheIslandIsNotFitted() {
        let panel = TestNotchContent(id: "panel", priority: 1, collapsedWidthOffset: 180, collapsedHeightOffset: 100)
        let model = NotchModel(liveActivityContent: panel, baseWidth: 107, baseHeight: 31, isDynamicIsland: true)

        XCTAssertEqual(model.size, CGSize(width: 107 + 180, height: 31 + 100))
    }

    func testModelsWithDifferentPanelBaseSizesAreNotEqual() {
        let content = TestNotchContent(id: "pill", priority: 1)
        let fitted = fittedModel(content: content)
        var other = fitted
        other.panelBaseSize = CGSize(width: 120, height: 31)

        XCTAssertNotEqual(fitted, other)
    }

    // MARK: - View model

    @MainActor
    func testViewModelPublishesTheFittedBaseSizeAndTopOffset() {
        let viewModel = NotchViewModel(
            settings: TestNotchSettings(),
            screenMetricsProvider: { _ in
                (width: 3008, topInset: 0, notchSize: nil, menuBarHeight: 30)
            }
        )
        TestLifetime.retain(viewModel)

        XCTAssertTrue(viewModel.isDynamicIsland)
        XCTAssertEqual(viewModel.notchModel.baseHeight, 26, accuracy: 0.0001)
        XCTAssertEqual(viewModel.notchModel.size.height, 26, accuracy: 0.0001)
        XCTAssertEqual(viewModel.dynamicIslandTopOffset, 3, accuracy: 0.0001)
        XCTAssertEqual(viewModel.notchModel.panelBaseSize?.height ?? 0, 31, accuracy: 0.0001)
    }

    @MainActor
    func testViewModelKeepsTheDefaultTopOffsetWithoutAMenuBarHeight() {
        let viewModel = NotchViewModel(
            settings: TestNotchSettings(),
            screenMetricsProvider: { _ in
                (width: 3008, topInset: 0, notchSize: nil, menuBarHeight: nil)
            }
        )
        TestLifetime.retain(viewModel)

        XCTAssertEqual(viewModel.notchModel.baseHeight, 31, accuracy: 0.0001)
        XCTAssertEqual(viewModel.dynamicIslandTopOffset, 9, accuracy: 0.0001)
        XCTAssertNil(viewModel.notchModel.panelBaseSize)
    }

    // MARK: - Helpers

    /// The fitted island is 90 x 26 points, compared with 107 x 31 points without the fit.
    private func fittedModel(content: TestNotchContent) -> NotchModel {
        var model = NotchModel(liveActivityContent: content, baseWidth: 90, baseHeight: 26, isDynamicIsland: true)
        model.panelBaseSize = CGSize(width: 107, height: 31)
        return model
    }

    @MainActor
    private func geometry(
        menuBarHeight: CGFloat?,
        notchWidthSetting: Double = 0,
        notchHeightSetting: Double = 0
    ) -> CalculatedNotchGeometry {
        geometry(
            metrics: (width: 3008, topInset: 0, notchSize: nil, menuBarHeight: menuBarHeight),
            notchWidthSetting: notchWidthSetting,
            notchHeightSetting: notchHeightSetting
        )
    }

    @MainActor
    private func geometry(
        metrics: NotchScreenMetrics,
        notchWidthSetting: Double = 0,
        notchHeightSetting: Double = 0
    ) -> CalculatedNotchGeometry {
        NotchGeometryCoordinator().calculateGeometry(
            screenMetrics: metrics,
            notchWidthSetting: notchWidthSetting,
            notchHeightSetting: notchHeightSetting
        )
    }
}
