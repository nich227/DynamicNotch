import Foundation
import Lottie
internal import AppKit

/// This recolors the gradients of a Lottie animation with the system accent color.
///
/// The animations ship with blue gradients. Each gradient stop keeps its brightness and its place in the gradient.
/// Its hue moves from the reference blue to the accent hue. Its saturation scales with the accent's saturation, so a
/// gray accent gives a gray gradient.
nonisolated enum AccentGradient {
    /// The hue of the shipped gradients is expressed as a fraction of a turn.
    static let referenceHue = 208.0 / 360.0

    static func animation(named name: String, accent: NSColor, bundle: Bundle = .main) -> LottieAnimation? {
        guard let url = bundle.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let color = accent.usingColorSpace(.sRGB) else {
            return nil
        }
        let hsb = hsb(red: Double(color.redComponent), green: Double(color.greenComponent), blue: Double(color.blueComponent))
        guard let recolored = recolor(animationJSON: data, accentHue: hsb.hue, accentSaturation: hsb.saturation) else {
            return nil
        }
        return try? LottieAnimation.from(data: recolored)
    }

    /// Returns the animation with every static gradient recolored, or nil when the data is not a JSON object.
    static func recolor(animationJSON: Data, accentHue: Double, accentSaturation: Double) -> Data? {
        guard let root = try? JSONSerialization.jsonObject(with: animationJSON) as? [String: Any] else {
            return nil
        }
        let recolored = recolor(root, accentHue: accentHue, accentSaturation: accentSaturation)
        return try? JSONSerialization.data(withJSONObject: recolored)
    }

    /// A Lottie gradient lists its color stops first. Each stop has four numbers: offset, red, green, and blue.
    static func recolored(stops: [Double], colorStopCount: Int, accentHue: Double, accentSaturation: Double) -> [Double] {
        var result = stops
        for stop in 0..<colorStopCount where stop * 4 + 3 < stops.count {
            let base = stop * 4
            let original = hsb(red: stops[base + 1], green: stops[base + 2], blue: stops[base + 3])
            let hue = (accentHue + original.hue - referenceHue).truncatingRemainder(dividingBy: 1)
            let color = rgb(
                hue: hue < 0 ? hue + 1 : hue,
                saturation: min(1, original.saturation * accentSaturation),
                brightness: original.brightness
            )
            result[base + 1] = color.red
            result[base + 2] = color.green
            result[base + 3] = color.blue
        }
        return result
    }

    private static func recolor(_ value: Any, accentHue: Double, accentSaturation: Double) -> Any {
        if let array = value as? [Any] {
            return array.map { recolor($0, accentHue: accentHue, accentSaturation: accentSaturation) }
        }
        guard var object = value as? [String: Any] else {
            return value
        }
        for (key, child) in object {
            object[key] = recolor(child, accentHue: accentHue, accentSaturation: accentSaturation)
        }
        let type = object["ty"] as? String
        if type == "gs" || type == "gf",
           var gradient = object["g"] as? [String: Any],
           let count = gradient["p"] as? Int,
           var colors = gradient["k"] as? [String: Any],
           let stops = (colors["k"] as? [NSNumber])?.map(\.doubleValue) {
            colors["k"] = recolored(stops: stops, colorStopCount: count, accentHue: accentHue, accentSaturation: accentSaturation)
            gradient["k"] = colors
            object["g"] = gradient
        }
        return object
    }

    static func hsb(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, brightness: Double) {
        let maximum = max(red, green, blue)
        let delta = maximum - min(red, green, blue)
        guard delta > 0 else {
            return (0, 0, maximum)
        }
        let sector: Double
        if maximum == red {
            sector = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        } else if maximum == green {
            sector = (blue - red) / delta + 2
        } else {
            sector = (red - green) / delta + 4
        }
        let hue = sector / 6
        return (hue < 0 ? hue + 1 : hue, delta / maximum, maximum)
    }

    static func rgb(hue: Double, saturation: Double, brightness: Double) -> (red: Double, green: Double, blue: Double) {
        let scaled = hue * 6
        let chroma = brightness * saturation
        let second = chroma * (1 - abs(scaled.truncatingRemainder(dividingBy: 2) - 1))
        let floor = brightness - chroma
        let base: (Double, Double, Double)
        switch Int(scaled) % 6 {
        case 0: base = (chroma, second, 0)
        case 1: base = (second, chroma, 0)
        case 2: base = (0, chroma, second)
        case 3: base = (0, second, chroma)
        case 4: base = (second, 0, chroma)
        default: base = (chroma, 0, second)
        }
        return (base.0 + floor, base.1 + floor, base.2 + floor)
    }
}
