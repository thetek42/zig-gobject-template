# zig-gobject-template

This is a sample application illustrating how to use [zig-gobject](https://github.com/ianprime0509/zig-gobject).

## Features

- Gtk4 + LibAdwaita
- [Blueprints](https://gitlab.gnome.org/jwestman/blueprint-compiler)
- libintl (Translation)
- GSchema (Preferences)

## Usage

1. Replace all IDs and similar items to your desired values. Hint:
   ```sh
   grep -r --exclude-dir=zig-out --exclude-dir=.zig-cache "zig-gobject-template"`
   find -name "*zig-gobject-template*" -not -path "./zig-out/*" -not -path "./.zig-cache/*"
   ```
2. Build (and run) the application:
   ```sh
   zig build
   zig build run
   ```
