# Contributing to DynamicNotch

Thank you for taking the time to contribute.

DynamicNotch aims to bring a smooth, native, and polished iOS-style Dynamic Island experience to macOS. Community contributions make the app more reliable, add features, and improve accessibility for everyone.

Use these guidelines when contributing.

## Table of contents

- [Code of conduct](#code-of-conduct)
- [How can I contribute?](#how-can-i-contribute)
  - [Reporting bugs](#reporting-bugs)
  - [Suggesting enhancements](#suggesting-enhancements)
  - [Localizations and translations](#localizations-and-translations)
  - [Code contributions](#code-contributions)
- [Development setup](#development-setup)
- [Project architecture](#project-architecture)
- [Coding guidelines](#coding-guidelines)
- [Testing](#testing)
- [Pull request checklist](#pull-request-checklist)

---

## Code of conduct

By participating, you agree to keep this project respectful, welcoming, and collaborative. Give constructive feedback and respect other contributors.

---

## How can I contribute?

### Reporting bugs

If you find a bug, check the [Issues](https://github.com/nich227/DynamicNotch/issues) list first. If no one has reported it, open a new issue.

Include:
1. macOS version (e.g., macOS 14.6) and Mac model (e.g., MacBook Pro M3 Max).
2. App version (e.g., the latest GitHub release or a custom build).
3. Clear steps to reproduce the issue.
4. Expected and actual behavior.
5. Console logs, screenshots, or screen recordings showing the bug.

*Note: For security vulnerabilities, read the [Security Policy](SECURITY.md) and report it privately instead of opening a public issue.*

### Suggesting enhancements

DynamicNotch welcomes ideas for better animations, layouts, and feature support. To suggest an enhancement:
- Explain the behavior you want.
- Provide mockups or links to reference materials, such as iOS Dynamic Island behavior.
- Open an issue with the tag `enhancement`.

### Localizations and translations

This fork ships in English only. The strings are stored in `DynamicNotch/Resources/Localization/Localizable.xcstrings`. To add a language, add its translations to that string catalog and add the language to the known regions of the project.

### Code contributions

To fix a bug or add a feature:
1. Search the open issues, or open one to discuss your proposed change.
2. Fork the repository and create a descriptive branch, such as `git checkout -b feature/my-new-feature` or `bugfix/fix-some-bug`.
3. Keep your changes focused. Avoid large pull requests that mix unrelated fixes.

---

## Development setup

DynamicNotch requires:
- A Mac running macOS 14.6 or later.
- Xcode 15.0 or later.
- Basic knowledge of Swift, SwiftUI, and AppKit.

### Run the app

1. Clone the repository:
   ```bash
   git clone https://github.com/nich227/DynamicNotch.git
   cd DynamicNotch
   ```
2. Open the project in Xcode:
   ```bash
   open DynamicNotch.xcodeproj
   ```
3. Xcode resolves the Swift Package Manager (SPM) dependencies, including Lottie.
4. Select the `DynamicNotch` scheme and My Mac as the target.
5. Click Run (`Cmd + R`) to compile and start the app.

---

## Project architecture

DynamicNotch uses a modular, feature-based architecture. This structure makes each notch module easy to add, change, or disable.

```
DynamicNotch/
├── Application/        # App lifecycle, AppDelegate, and main entry points
├── Core/               # Shared core infrastructure (window controllers, managers, notification listeners)
├── Features/           # Self-contained modules for specific notch notifications & HUDs
│   ├── Battery/        # Battery charging notifications and HUD indicators
│   ├── Bluetooth/      # Bluetooth accessory connect/disconnect indicators
│   ├── NowPlaying/     # Now Playing media player controls, audio visualizer, lyrics
│   ├── Settings/       # User preferences window, customize sizes, styles
│   └── ...             # Other modules (Timer, Wifi, Focus, VPN, etc.)
├── Shared/             # Global extensions, UI utilities, standard models
└── Resources/          # Assets, Lottie files, localizations, and application icons
```

### Key concepts

- ViewModels manage logic, state, and event streams with Combine.
- Views use SwiftUI for declarative layouts.
- AppKit wrappers manage the notch overlay window. They track full-screen workspace changes, mouse and trackpad hover events, and system coordinate conversions.

---

## Coding guidelines

Follow these rules:

1. Match Dynamic Island behavior and UI.
   - New features and UI components must strictly match or closely resemble native iOS Dynamic Island behavior, layouts, and spring animations.
   - Do not add nonstandard UI elements that break Apple's design language. Use proper rounded corners, padding, and San Francisco typography.
2. Keep bug fixes targeted.
   - Fix the cause without changing unrelated business logic, existing view layouts, or user flows.
3. Follow the architecture.
   - Place each new feature in `DynamicNotch/Features/[FeatureName]`.
   - Keep views declarative. Delegate state and event handling to ViewModels.
4. Protect battery life and performance.
   - DynamicNotch runs as a background overlay. Avoid high-frequency polling, tight timer loops, and heavy background computations.
   - Prevent memory leaks. Use `[weak self]` for subscriptions and notification observers where appropriate.
   - Run UI updates on `@MainActor`.
5. Limit dependencies.
   - Add external SPM dependencies only when absolutely necessary and agreed upon. Use native macOS, AppKit, and SwiftUI APIs whenever possible.
6. Follow Swift conventions.
   - Write clear, self-documenting Swift code that follows the Swift API Design Guidelines.
   - Avoid force unwrapping (`!`).
   - Indent with 4 spaces.
   - Remove unused imports, dead code, debug `print()` statements, and commented-out code before submitting.

---

## Testing

The test suite is in the `DynamicNotchTests` folder.

- Press `Cmd + U` in Xcode to run all unit tests.
- Add tests for new features and bug fixes in `DynamicNotchTests/Features/[FeatureName]` to prevent regressions.

---

## Pull request checklist

Before submitting your pull request, confirm:
- [ ] New features and UI strictly follow native iOS Dynamic Island design and animations.
- [ ] Bug fixes do not change unrelated logic or UI.
- [ ] The code introduces no performance regressions, high-frequency polling, or memory leaks.
- [ ] The code introduces no unnecessary third-party dependencies.
- [ ] The project compiles without errors or new warnings.
- [ ] All unit tests pass (`Cmd + U`).
- [ ] The code follows project formatting and Swift conventions, has no leftover `print()` statements, and uses clean commits.
- [ ] The pull request includes screenshots or screen recordings for UI changes.
