### Description
<!-- 
EN: Briefly describe the changes, explain why they were made, and link related issues (e.g. Closes #123).
RU: Кратко опишите, что было сделано, зачем, и прикрепите связанные задачи (например, Closes #123).
-->

---

### Type of change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactoring and optimization
- [ ] Documentation and localization

---

### Pull request checklist and requirements

#### 1. Features and UI
- [ ] New features and UI match or closely follow native Apple Dynamic Island behavior, layouts, and physics-based spring animations on iOS.
- [ ] The design follows macOS and Dynamic Island guidelines for corner radii, padding, San Francisco typography, and a dark appearance.

#### 2. Bug fixes
- [ ] The fix does not change unrelated business logic, existing interfaces, or user expectations.
- [ ] Neighboring features and existing flows continue to work correctly.

#### 3. Code integrity and performance
- [ ] DynamicNotch is a background menu and notch app. Changes do not add tight loops, busy-waiting, redundant timers, or excessive background polling.
- [ ] Closures, Combine pipelines, and Notification pipelines have no retain cycles or memory leaks and use `[weak self]` correctly. UI updates run on `@MainActor`.
- [ ] Do not add external packages or frameworks unless they are necessary and discussed beforehand.

#### 4. Code quality and standards
- [ ] The code follows the project architecture (`DynamicNotch/Features/...` and MVVM).
- [ ] The code follows the Swift API Design Guidelines, does not use the force unwrap operator `!`, uses clear names, and uses four-space indentation.
- [ ] Remove all debug `print()` statements, test flags, and commented-out code.

#### 5. Verification and testing
- [ ] The project builds without new warnings or errors.
- [ ] Existing and new unit tests pass (`Cmd + U`).
- [ ] Test the change on a physical Mac (macOS version: `macOS ________`).
- [ ] Attach screenshots or screen recordings below, especially for UI or animation changes.

---

### Media, screenshots, and recordings
<!-- Attach screenshots, GIFs, or videos that show the changes. -->
