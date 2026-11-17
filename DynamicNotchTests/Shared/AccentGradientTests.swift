import AppKit
import XCTest
@testable import DynamicNotch

final class AccentGradientTests: XCTestCase {
    /// These two stops use the shipped blue. One is dark and saturated, and the other is pale.
    private let blueStops = [0.0, 0.031, 0.341, 0.627, 1.0, 0.851, 0.878, 0.902]

    private func stops(of data: Data) throws -> [Double] {
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let layers = try XCTUnwrap(root["layers"] as? [[String: Any]])
        let shapes = try XCTUnwrap(layers[0]["shapes"] as? [[String: Any]])
        let items = try XCTUnwrap(shapes[0]["it"] as? [[String: Any]])
        let stroke = try XCTUnwrap(items.first { $0["ty"] as? String == "gs" })
        let gradient = try XCTUnwrap(stroke["g"] as? [String: Any])
        let colors = try XCTUnwrap(gradient["k"] as? [String: Any])
        return try XCTUnwrap(colors["k"] as? [NSNumber]).map(\.doubleValue)
    }

    func testHueFollowsTheAccentAndBrightnessStays() {
        let red = AccentGradient.recolored(stops: blueStops, colorStopCount: 2, accentHue: 0, accentSaturation: 1)

        XCTAssertEqual(red[0], 0)
        XCTAssertEqual(red[4], 1)
        for stop in [0, 4] {
            let before = AccentGradient.hsb(red: blueStops[stop + 1], green: blueStops[stop + 2], blue: blueStops[stop + 3])
            let after = AccentGradient.hsb(red: red[stop + 1], green: red[stop + 2], blue: red[stop + 3])
            XCTAssertEqual(after.brightness, before.brightness, accuracy: 0.001)
            XCTAssertEqual(after.saturation, before.saturation, accuracy: 0.001)
            let hue = min(after.hue, 1 - after.hue)
            XCTAssertEqual(hue, 0, accuracy: 0.01, "a red accent gives red stops")
        }
    }

    func testAccentAtTheReferenceHueKeepsTheShippedColors() {
        let same = AccentGradient.recolored(
            stops: blueStops, colorStopCount: 2, accentHue: AccentGradient.referenceHue, accentSaturation: 1
        )

        for (after, before) in zip(same, blueStops) {
            XCTAssertEqual(after, before, accuracy: 0.001)
        }
    }

    func testGrayAccentGivesGrayStops() {
        let gray = AccentGradient.recolored(stops: blueStops, colorStopCount: 2, accentHue: 0.6, accentSaturation: 0)

        XCTAssertEqual(gray[1], gray[2], accuracy: 0.001)
        XCTAssertEqual(gray[2], gray[3], accuracy: 0.001)
        XCTAssertEqual(gray[3], 0.627, accuracy: 0.001, "the brightness of the stop stays")
    }

    func testNumbersAfterTheColorStopsStay() {
        let withOpacity = blueStops + [0.0, 1.0, 1.0, 0.5]

        let recolored = AccentGradient.recolored(stops: withOpacity, colorStopCount: 2, accentHue: 0.1, accentSaturation: 1)

        XCTAssertEqual(Array(recolored.suffix(4)), [0.0, 1.0, 1.0, 0.5])
        XCTAssertEqual(AccentGradient.recolored(stops: [0.0, 0.1], colorStopCount: 2, accentHue: 0.1, accentSaturation: 1), [0.0, 0.1])
    }

    func testColorConversionRoundTripsOnEverySector() {
        for hue in stride(from: 0.02, to: 1.0, by: 0.09) {
            let color = AccentGradient.rgb(hue: hue, saturation: 0.7, brightness: 0.8)
            let back = AccentGradient.hsb(red: color.red, green: color.green, blue: color.blue)
            XCTAssertEqual(back.hue, hue, accuracy: 0.001)
            XCTAssertEqual(back.saturation, 0.7, accuracy: 0.001)
            XCTAssertEqual(back.brightness, 0.8, accuracy: 0.001)
        }

        let gray = AccentGradient.hsb(red: 0.5, green: 0.5, blue: 0.5)
        XCTAssertEqual(gray.saturation, 0)
        XCTAssertEqual(gray.brightness, 0.5)
    }

    func testRecolorsEveryGradientInTheAnimationAndNothingElse() throws {
        let json = """
        {"w":10,"layers":[{"shapes":[{"ty":"gr","it":[
          {"ty":"gs","g":{"p":2,"k":{"a":0,"k":[0,0.031,0.341,0.627,1,0.851,0.878,0.902]}},"w":{"k":9}},
          {"ty":"fl","c":{"k":[0.031,0.341,0.627,1]}}
        ]}]}]}
        """
        let recolored = try XCTUnwrap(AccentGradient.recolor(animationJSON: Data(json.utf8), accentHue: 0, accentSaturation: 1))

        let after = try stops(of: recolored)
        XCTAssertGreaterThan(after[1], after[3], "the first stop is now red, not blue")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: recolored) as? [String: Any])
        XCTAssertEqual(root["w"] as? Int, 10)
        let layers = try XCTUnwrap(root["layers"] as? [[String: Any]])
        let shapes = try XCTUnwrap(layers[0]["shapes"] as? [[String: Any]])
        let items = try XCTUnwrap(shapes[0]["it"] as? [[String: Any]])
        let fill = try XCTUnwrap((items[1]["c"] as? [String: Any])?["k"] as? [NSNumber]).map(\.doubleValue)
        XCTAssertEqual(fill, [0.031, 0.341, 0.627, 1], "the fill color is not a gradient and stays")
    }

    func testAnimatedGradientStaysAsItIs() throws {
        let json = """
        {"layers":[{"shapes":[{"ty":"gr","it":[
          {"ty":"gs","g":{"p":2,"k":{"a":1,"k":[{"t":0,"s":[0,0.031,0.341,0.627,1,0.851,0.878,0.902]}]}}}
        ]}]}]}
        """
        let recolored = try XCTUnwrap(AccentGradient.recolor(animationJSON: Data(json.utf8), accentHue: 0, accentSaturation: 1))

        let before = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary)
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: recolored) as? NSDictionary)
        XCTAssertEqual(after, before)
    }

    func testDataThatIsNotAnAnimationGivesNil() {
        XCTAssertNil(AccentGradient.recolor(animationJSON: Data("[1, 2]".utf8), accentHue: 0, accentSaturation: 1))
        XCTAssertNil(AccentGradient.recolor(animationJSON: Data("not json".utf8), accentHue: 0, accentSaturation: 1))
    }

    func testLoadsTheHelloAnimationTintedWithTheAccent() {
        XCTAssertNotNil(AccentGradient.animation(named: "hello", accent: .systemOrange))
        XCTAssertNil(AccentGradient.animation(named: "no-such-animation", accent: .systemOrange))
        XCTAssertNil(
            AccentGradient.animation(named: "hello", accent: NSColor(patternImage: NSImage(size: NSSize(width: 1, height: 1)))),
            "a color with no red, green, and blue parts cannot tint"
        )
    }

    func testFilesThatAreNotAnimationsGiveNil() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AccentGradientTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("[1, 2]".utf8).write(to: directory.appendingPathComponent("list.json"))
        try Data("{}".utf8).write(to: directory.appendingPathComponent("empty.json"))
        let bundle = try XCTUnwrap(Bundle(path: directory.path))

        XCTAssertNil(AccentGradient.animation(named: "list", accent: .systemOrange, bundle: bundle))
        XCTAssertNil(AccentGradient.animation(named: "empty", accent: .systemOrange, bundle: bundle))
    }
}
