# zig-gobject-template

This is a sample application illustrating how to use [zig-gobject](https://github.com/ianprime0509/zig-gobject).

## Features

- Gtk4 + LibAdwaita
- [Blueprints](https://gitlab.gnome.org/GNOME/blueprint-compiler)
- libintl (Translation)
- GSchema (Preferences)

## Dependencies

- Linux
  - It is not possible to compile this on Windows (see [here](https://github.com/ianprime0509/zig-gobject/issues/50))
  - To obtain a binary that works on Windows, you have to cross-compile as described [below](#building-for-windows) (e.g. from WSL)
- Zig 0.14 (or higher)
- GNOME / GTK development libraries
  - If you are targeting Linux, two options are available:
    - Install the GNOME SDK as described [here](https://github.com/ianprime0509/zig-gobject?tab=readme-ov-file#development-environment). You might possibly also need to install Libintl separately, I'm not sure about that.
    - Install GTK, Libadwaita and Libintl with your system's package manager. GTK 4.16 and 4.18 are tested and work fine, older and newer versions should hopefully work as well.
  - If you are targeting Windows, run `sh fetch-windows-libs.sh` as described [below](#building-for-windows).
- [Blueprint Compiler](https://gitlab.gnome.org/GNOME/blueprint-compiler)

## Usage

1. Replace all IDs and similar items to your desired values. Hint:
   ```sh
   grep -r --exclude-dir=zig-out --exclude-dir=.zig-cache "zig-gobject-template"
   find -name "*zig-gobject-template*" -not -path "./zig-out/*" -not -path "./.zig-cache/*"
   ```
2. Build (and run) the application:
   ```sh
   zig build
   zig build run
   ```

### Building for Windows

Since building natively on Windows does not work paricularly well, you need to
cross-compile the application from Linux:

```sh
# fetch required libraries dependencies (only required the first time)
sh fetch-windows-libs.sh
# cross-compile to windows
zig build -Dtarget=x86_64-windows
```
