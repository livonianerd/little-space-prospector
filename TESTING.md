# Verification record

Engine: Godot 4.7.2.stable.official.ed1daf0bf. Local host: Ubuntu 24.04, software OpenGL renderer (Mesa llvmpipe).

- Headless project import: passed. Sandboxed editor reported unavailable local debugger sockets; no script import errors.
- Gameplay smoke test: passed, zero failures. Exercises actual flight to each component, installing all three, duplicate installation and purchase protection, resource regrowth, and safe recovery.
- Native visual inspection: passed at 960×640. Captured gameplay and completed workshop with all decorations using `tests/capture.gd`.
- Save/load round-trip: passed for character, ship components and installations, currency, and owned decoration, using an isolated test save.
- Local Web and Linux release exports: passed with matching 4.7.2 templates. Web mobile texture import configuration corrected during validation.
- Exported Linux binary: headless launch passed locally and in the Ubuntu 22.04 Actions runner.
- Windows x86-64 release export: passed locally using the project's pinned Godot 4.7.2 editor and matching Windows export templates. The executable is identified as PE32+ x86-64; the separate `.pck` is included with it in the ZIP. Gameplay smoke tests still pass with zero failures. Windows runtime and graphical play remain unverified; this environment cross-exports from Linux.
- Chromium WebGL browser: loaded successfully beneath `/build/web/`, with no script, HTTP, or browser console errors. Keyboard movement collected the first part; workshop opened correctly. Captures inspected visually. Missing web font glyphs corrected.
- Browser persistence: reload retained collected gold, diamonds, the first ship part, and selected astronaut, verified in the rendered counters and character.
- Landscape mobile Chromium emulation (844×390): touch menus and simultaneous right + jet input exercised. Controls remain on-screen with large pads. This is emulation, not a physical device.

The browser check is reproducible with `tools/browser-check.cjs` and Playwright installed separately. Serve the repository on port 8000, then run `NODE_PATH=/path/to/node_modules node tools/browser-check.cjs`. It asserts absence of browser/HTTP errors and saves screenshots in `/tmp` for visual verification; it does not assert pixel-perfect rendering.

Physical Android/iOS device testing is not available in this environment. Real mobile GPU performance, Safari/iOS browser behavior, interruptions, and browser storage eviction remain unverified. Browser emulation does not replace physical device testing.
