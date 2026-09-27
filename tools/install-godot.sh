#!/usr/bin/env bash
set -euo pipefail
# One version source for all workflows; editor and templates always match.
GODOT_VERSION=4.7.2
base="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"
mkdir -p .tools
curl --fail --location --retry 3 "$base/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o .tools/editor.zip
curl --fail --location --retry 3 "$base/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -o .tools/templates.zip
unzip -oq .tools/editor.zip -d .tools
mv ".tools/Godot_v${GODOT_VERSION}-stable_linux.x86_64" .tools/godot
chmod +x .tools/godot
template_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}.stable"
mkdir -p "$template_dir"
unzip -oq .tools/templates.zip 'templates/*' -d .tools
cp -a .tools/templates/. "$template_dir/"
.tools/godot --version
