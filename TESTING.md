# Verification record

Engine: Godot 4.7.2.stable.official.ed1daf0bf. Local host: Ubuntu 24.04, software OpenGL renderer (Mesa llvmpipe).

- Headless project import: passed. Sandboxed editor reported unavailable local debugger sockets; no script import errors.
- Gameplay smoke test: passed, zero failures. Exercises actual flight to each component, installing all three, duplicate installation and purchase protection, resource regrowth, and safe recovery.
- Native visual inspection: passed at 960×640. Captured gameplay and completed workshop with all decorations using `tests/capture.gd`.
- Export, browser, and Ubuntu 22.04 workflow results will be recorded after execution.

Physical Android/iOS device testing is not available in this environment. Real mobile GPU performance, Safari/iOS browser behavior, interruptions, and browser storage eviction remain unverified. Browser emulation does not replace physical device testing.
