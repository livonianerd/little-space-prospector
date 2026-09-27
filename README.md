# Little Space Prospector

A cheerful, original 2D asteroid garden made in **Godot 4.7.2 stable**, GDScript, and the Compatibility renderer. Choose a boy or girl astronaut, float between seven asteroids, and collect three components to assemble your own spaceship. No enemies, death, fuel, or time pressure.

## Play

Published address after the Pages workflow succeeds: **https://livonianerd.github.io/little-space-prospector/**

Collect the glowing **PART** crates on gardens 01, 03, and 05. Open **Ship** anywhere and install each part: hull, cabin, then engines. Gold buys golden fins; diamonds buy a crystal window; both buy garden lights. The completed ship and decorations are visible at home and in the workshop. **Home** regrows resources so collecting can continue indefinitely.

| Input | Action |
| --- | --- |
| A / D or left / right arrows | Steer |
| Hold Space, W, or up arrow | Hop and gently jet upward |
| B / Ship button | Open workshop |
| Escape | Close workshop |
| R / Home button | Return home and regrow resources |
| Touch | Hold an arrow and JET together; tap menus |
| Mouse only | Hold an arrow pad to steer with automatic lift; release to land |

On phones, play in **landscape** for large controls. Touch supports simultaneous steering and jetpack input. Missing an asteroid returns you to your most recent safe landing, with your discoveries intact.

Progress saves after collections, purchases, installations, and character selection. Desktop saves live in Godot's `user://` folder (`~/.local/share/godot/app_userdata/Little Space Prospector/` on Linux). Web saves use browser storage for that site; private browsing or clearing site data can remove them. Reloading starts at home with your inventory and ship restored.

## Run locally

1. Download **Godot 4.7.2 stable**, standard edition, from https://godotengine.org/download/archive/4.7.2-stable/.
2. Import `project.godot` and press F6 on `main.tscn` or F5 to play.
3. For command-line play: `godot --path .`.

All art is drawn in `scripts/game.gd`, plus the original SVG icon in `assets/`. There are no paid assets, runtime services, plugins, or dependencies.

## Export locally

Install the matching **4.7.2** export templates via Godot's editor, or run `bash tools/install-godot.sh` on Linux (requires curl and unzip). That script installs an editor at `.tools/godot` and matching templates in Godot's data directory.

```sh
.tools/godot --headless --editor --path . --import --quit
.tools/godot --headless --path . --script tests/smoke.gd -- --smoke-test
mkdir -p build/web build/linux
.tools/godot --headless --path . --export-release Web build/web/index.html
.tools/godot --headless --path . --export-release Linux build/linux/little-space-prospector.x86_64
python3 -m http.server 8000 --directory build/web
```

Open http://localhost:8000. Serve the web export over HTTP(S), not `file://`. The web preset is single-threaded and uses relative asset paths; it needs no cross-origin isolation headers and works under a GitHub repository subpath. A WebGL 2-capable browser is required.

## GitHub Pages setup

1. Push this repository to `main` on GitHub.
2. In **Settings → Pages → Build and deployment**, choose **GitHub Actions**.
3. In **Actions**, run **Web game and GitHub Pages**, or push to `main`.
4. The deployment job reports the live address: `https://USERNAME.github.io/REPOSITORY/`.

`.github/workflows/web.yml` imports, tests, exports, and deploys the game. `.github/workflows/linux.yml` separately builds Linux. Both run on Ubuntu 22.04 and install the editor and templates using the same pinned version in `tools/install-godot.sh`.

## Linux download and run

Open https://github.com/livonianerd/little-space-prospector/actions/workflows/linux.yml, select a successful run, and download the **little-space-prospector-linux-x86_64** artifact. GitHub requires sign-in for Actions artifact downloads. Extract the artifact wrapper, then extract the game ZIP inside it. Keep the executable and `.pck` file together:

```sh
chmod +x little-space-prospector.x86_64
./little-space-prospector.x86_64
```

Targets **Ubuntu 22.04 x86-64** with OpenGL 3.3 support. The workflow launches the exported binary headlessly on Ubuntu 22.04 before packaging it. Pushing a `v*` tag also attaches the ZIP to a GitHub Release for public downloads without signing in.

## Verification

`tests/smoke.gd` flies the real movement simulation to all three parts and checks ship completion, duplicate-install protection, purchase accounting, missed-jump recovery, and regrowth. Run with `-- --smoke-test` to disable normal saves. See `TESTING.md` for executed checks and remaining device coverage.
